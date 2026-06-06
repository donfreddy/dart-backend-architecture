import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:dart_backend_architecture/app.dart';
import 'package:dart_backend_architecture/config.dart';
import 'package:dart_backend_architecture/core/logger.dart';
import 'package:dart_backend_architecture/core/telemetry/otel_setup.dart'
    show initTelemetry, shutdownTelemetry;
import 'package:dart_backend_architecture/di/composition_root.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

// -- Isolate protocol ---------------------------------------------------------

sealed class IsolateMessage {}

/// Sent by the main isolate to initiate a graceful shutdown.
final class ShutdownCommand extends IsolateMessage {}

/// Sent by a worker once its resources have been released.
final class ShutdownAck extends IsolateMessage {
  final int workerId;
  ShutdownAck(this.workerId);
}

/// Sent by a worker once it is ready to serve traffic.
///
/// Carries [workerId] so the main dispatch can route without relying
/// on stream ordering — required for parallel spawn.
final class WorkerReady extends IsolateMessage {
  final int workerId;
  final SendPort controlPort;
  WorkerReady(this.workerId, this.controlPort);
}

// -- Value objects ------------------------------------------------------------

/// Spawn argument for [_workerEntryPoint].
///
/// All fields must be primitives or [SendPort]s — [Isolate.spawn] requires
/// a message-passable value.
final class WorkerConfig {
  final int id;

  /// Used by the worker to send [WorkerReady] and [ShutdownAck] to main.
  final SendPort mainPort;



  const WorkerConfig({
    required this.id,
    required this.mainPort,
  });
}

// -- Entry point --------------------------------------------------------------

Future<void> main() async {
  AppLogger.configure();
  await initTelemetry();

  final config = AppConfig.fromEnv();
  final log = AppLogger.get('main');

  final workerCount =
      config.workerCount > 0 ? config.workerCount : Platform.numberOfProcessors;

  log.info('Starting $workerCount isolate(s) on port ${config.port}');

  // Validate total DB connections won't exceed PostgreSQL max_connections.
  final totalPoolConnections = workerCount * config.dbPoolSize;
  const pgMaxConnections = 100;
  if (totalPoolConnections > pgMaxConnections) {
    log.severe(
      'WORKER_COUNT ($workerCount) × DB_POOL_SIZE (${config.dbPoolSize}) '
      '= $totalPoolConnections > PostgreSQL max_connections ($pgMaxConnections).\n'
      'Reduce WORKER_COUNT or DB_POOL_SIZE in .env, or increase '
      'max_connections in postgresql.conf.',
    );
    exit(1);
  }

  // Single inbound port for all worker messages; broadcast so multiple
  // subscribers (boot + runtime) coexist.
  final mainPort = ReceivePort();
  final mainStream = mainPort.asBroadcastStream();

  // Runtime state — populated at boot and updated on respawn.
  final workerControlPorts = <int, SendPort>{};
  final workerAckCompleters = <int, Completer<void>>{};

  // Boot completers — resolved once, never used again after boot.
  final readyCompleters = <int, Completer<SendPort>>{
    for (var i = 1; i < workerCount; i++) i: Completer<SendPort>(),
  };

  // Persistent subscription handles WorkerReady (boot + respawn) and
  // ShutdownAck. Stays alive for the entire process lifetime.
  mainStream.listen((message) {
    switch (message) {
      case WorkerReady(:final workerId, :final controlPort):
        workerControlPorts[workerId] = controlPort;
        readyCompleters[workerId]?.complete(controlPort);
      case ShutdownAck(:final workerId):
        workerAckCompleters[workerId]?.complete();
      case _:
        log.warning('Unexpected message from worker: $message');
    }
  });

  void spawnWorker(int id) {
    unawaited(
      Isolate.spawn(
        _workerEntryPoint,
        WorkerConfig(
          id: id,
          mainPort: mainPort.sendPort,
        ),
        debugName: 'worker-$id',
        onError: _createErrorHandler(
          workerId: id,
          onCrash: () {
            log.severe('[worker-$id] crashed — respawning in 2s');
            Future.delayed(
              const Duration(seconds: 2),
              () => spawnWorker(id),
            );
          },
          log: log,
        ).sendPort,
      ),
    );
  }

  // Spawn all isolates in parallel.
  for (var i = 1; i < workerCount; i++) {
    spawnWorker(i);
  }

  // Wait for all workers to be ready before serving traffic.
  await Future.wait(
    readyCompleters.values.map(
      (c) => c.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('A worker failed to start'),
      ),
    ),
  );

  // The main isolate acts as worker-0.
  final mainServer = await _bindServer(config);
  final mainRoot = await CompositionRoot.initialize(config);

  shelf_io.serveRequests(
    mainServer,
    buildApp(
      mainRoot.router,
      maxRequestBodyBytes: config.maxRequestBodyBytes,
      apiKeyRepo: mainRoot.apiKeyRepo,
    ),
  );

  log.info('[worker-0] Listening on :${mainServer.port}');

  // Only the main isolate listens for OS signals.
  await Future.any([
    ProcessSignal.sigterm.watch().first,
    ProcessSignal.sigint.watch().first,
  ]);

  log.info('Shutdown signal received — draining workers...');

  for (final controlPort in workerControlPorts.values) {
    controlPort.send(ShutdownCommand());
  }

  await Future.wait([
    _gracefulStop(server: mainServer, root: mainRoot, log: log, workerId: 0),
    ...workerControlPorts.keys.map(
      (id) => (workerAckCompleters[id]?.future ?? Future.value()).timeout(
        const Duration(seconds: 25),
        onTimeout: () => log.warning('[worker-$id] ACK timeout'),
      ),
    ),
  ]);

  mainPort.close();
  log.info('All workers stopped.');
  exit(0);
}

// -- Worker -------------------------------------------------------------------

/// Entry point for each spawned isolate.
///
/// Workers do not listen for OS signals — shutdown is coordinated
/// exclusively by the main isolate via [ShutdownCommand].
Future<void> _workerEntryPoint(WorkerConfig config) async {
  AppLogger.configure();
  await initTelemetry();
  final log = AppLogger.get('worker-${config.id}');
  final controlPort = ReceivePort();

  try {
    final appConfig = AppConfig.fromEnv();
    final server = await _bindServer(appConfig);

    final root = await CompositionRoot.initialize(appConfig);

    shelf_io.serveRequests(
      server,
      buildApp(
        root.router,
        maxRequestBodyBytes: appConfig.maxRequestBodyBytes,
        apiKeyRepo: root.apiKeyRepo,
      ),
    );

    config.mainPort.send(WorkerReady(config.id, controlPort.sendPort));
    log.info('Listening on :${server.port}');

    await for (final message in controlPort) {
      switch (message) {
        case ShutdownCommand():
          await _gracefulStop(
            server: server,
            root: root,
            log: log,
            workerId: config.id,
          );
          config.mainPort.send(ShutdownAck(config.id));
          controlPort.close();
        case _:
          log.warning('Unexpected message: $message');
      }
    }
  } catch (e, st) {
    log.severe('Worker ${config.id} crashed', e, st);
    controlPort.close();
    exit(1);
  }
}

// -- Helpers ------------------------------------------------------------------

/// Binds an HTTP server shared across all isolates on the same port.
///
/// `shared: true` lets the OS distribute incoming connections across isolates.
Future<HttpServer> _bindServer(AppConfig config) async {
  final server = await HttpServer.bind(
    InternetAddress.anyIPv4,
    config.port,
    shared: true,
  );
  server.autoCompress = true;
  server.idleTimeout = const Duration(seconds: 30);
  return server;
}

/// Drains in-flight requests, then disposes infrastructure resources.
///
/// The 15 s drain timeout is intentionally shorter than the 25 s ACK timeout
/// in [main], leaving headroom for [CompositionRoot.dispose] to complete.
Future<void> _gracefulStop({
  required HttpServer server,
  required CompositionRoot root,
  required Logger log,
  required int workerId,
}) async {
  log.info('[worker-$workerId] Draining...');

  await server.close(force: false).timeout(
    const Duration(seconds: 15),
    onTimeout: () {
      log.warning('[worker-$workerId] Drain timeout — forcing close');
      return server.close(force: true);
    },
  );

  await root.dispose();
  await shutdownTelemetry();
  log.info('[worker-$workerId] Stopped.');
}

/// Returns a [RawReceivePort] that logs uncaught isolate errors and
/// triggers a delayed respawn via [onCrash].
RawReceivePort _createErrorHandler({
  required int workerId,
  required void Function() onCrash,
  required Logger log,
}) {
  return RawReceivePort((dynamic error) {
    log.severe('[worker-$workerId] Uncaught error: $error');
    onCrash();
  });
}
