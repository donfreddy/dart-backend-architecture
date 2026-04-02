import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';

import 'package:dart_backend_architecture/app.dart';
import 'package:dart_backend_architecture/config.dart';
import 'package:dart_backend_architecture/core/logger.dart';
import 'package:dart_backend_architecture/core/telemetry/otel_setup.dart';
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

// -- Semaphore ----------------------------------------------------------------

/// Limits concurrent [CompositionRoot.initialize] calls across isolates.
///
/// Isolates share no heap, so this is a message-passing token pool hosted
/// in the main isolate.
///
/// Protocol:
/// - Worker sends its own [SendPort] to [acquirePort] to request a slot.
/// - Semaphore sends a grant to that port when a slot is available.
/// - Worker sends any value back to [acquirePort] to release the slot.
final class InitSemaphore {
  final ReceivePort _port;
  final SendPort acquirePort;
  int _available;
  final Queue<SendPort> _waiting = Queue();

  InitSemaphore._(this._port, int concurrency)
      : acquirePort = _port.sendPort,
        _available = concurrency {
    _port.listen(_dispatch);
  }

  factory InitSemaphore(int concurrency) =>
      InitSemaphore._(ReceivePort(), concurrency);

  void _dispatch(dynamic msg) {
    if (msg is SendPort) {
      // Acquire request — grant immediately or enqueue.
      if (_available > 0) {
        _available--;
        msg.send(_grant);
      } else {
        _waiting.add(msg);
      }
    } else {
      // Release — forward to next waiter or return slot to pool.
      if (_waiting.isNotEmpty) {
        _waiting.removeFirst().send(_grant);
      } else {
        _available++;
      }
    }
  }

  static const _grant = true;

  void close() => _port.close();
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

  /// Worker acquires a slot here before [CompositionRoot.initialize],
  /// then sends any value back to release it.
  final SendPort semaphorePort;

  const WorkerConfig({
    required this.id,
    required this.mainPort,
    required this.semaphorePort,
  });
}

/// Main-side reference to a running worker.
final class WorkerHandle {
  final int id;
  final SendPort controlPort;
  final Completer<void> ackCompleter;

  WorkerHandle({
    required this.id,
    required this.controlPort,
    required this.ackCompleter,
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

  // Caps concurrent DB pool negotiations at boot.
  // With min:2/max:10 per worker and concurrency:4, the burst is ≤40
  // connections — within Postgres defaults.
  final semaphore = InitSemaphore(config.initConcurrency);

  // Single inbound port for all worker messages; broadcast so the
  // dispatch subscription and per-worker futures coexist.
  final mainPort = ReceivePort();
  final mainStream = mainPort.asBroadcastStream();

  // Pre-allocate completers before spawning so the dispatch listener
  // can resolve them regardless of message arrival order.
  final readyCompleters = <int, Completer<SendPort>>{
    for (var i = 1; i < workerCount; i++) i: Completer<SendPort>(),
  };
  final ackCompleters = <int, Completer<void>>{
    for (var i = 1; i < workerCount; i++) i: Completer<void>(),
  };

  // Centralized dispatch — one subscription routes all worker messages.
  final sub = mainStream.listen((message) {
    switch (message) {
      case WorkerReady(:final workerId, :final controlPort):
        readyCompleters[workerId]?.complete(controlPort);
      case ShutdownAck(:final workerId):
        ackCompleters[workerId]?.complete();
      case _:
        log.warning('Unexpected message from worker: $message');
    }
  });

  // Spawn all isolates in parallel — Isolate.spawn is cheap.
  // DB init concurrency is throttled inside each worker via the semaphore.
  for (var i = 1; i < workerCount; i++) {
    unawaited(Isolate.spawn(
      _workerEntryPoint,
      WorkerConfig(
        id: i,
        mainPort: mainPort.sendPort,
        semaphorePort: semaphore.acquirePort,
      ),
      debugName: 'worker-$i',
      onError: _isolateErrorPort(i, log).sendPort,
    ));
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

  await sub.cancel();
  semaphore.close();

  // Completers are all resolved — extract synchronously.
  final workers = [
    for (var i = 1; i < workerCount; i++)
      WorkerHandle(
        id: i,
        controlPort: await readyCompleters[i]!.future,
        ackCompleter: ackCompleters[i]!,
      ),
  ];

  // The main isolate acts as worker-0 and bypasses the semaphore —
  // it initializes after all workers are up to avoid contention.
  final mainServer = await _bindServer(config);
  final mainRoot = await CompositionRoot.initialize(config);

  shelf_io.serveRequests(
    mainServer,
    buildApp(mainRoot.router, maxRequestBodyBytes: config.maxRequestBodyBytes),
  );

  log.info('[worker-0] Listening on :${mainServer.port}');

  // Only the main isolate listens for OS signals.
  await Future.any([
    ProcessSignal.sigterm.watch().first,
    ProcessSignal.sigint.watch().first,
  ]);

  log.info('Shutdown signal received — draining workers...');

  for (final w in workers) {
    w.controlPort.send(ShutdownCommand());
  }

  await Future.wait([
    _gracefulStop(server: mainServer, root: mainRoot, log: log, workerId: 0),
    ...workers.map(
      (w) => w.ackCompleter.future.timeout(
        const Duration(seconds: 25),
        onTimeout: () => log.warning('[worker-${w.id}] ACK timeout'),
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
/// Acquires a semaphore slot before [CompositionRoot.initialize] to cap
/// concurrent DB pool negotiations during boot.
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

    // Acquire — blocks until the semaphore grants a slot.
    final grantPort = ReceivePort();
    config.semaphorePort.send(grantPort.sendPort);
    await grantPort.first;
    grantPort.close();

    final root = await CompositionRoot.initialize(appConfig);

    // Release immediately — before serving traffic.
    config.semaphorePort.send(true);

    shelf_io.serveRequests(
      server,
      buildApp(root.router, maxRequestBodyBytes: appConfig.maxRequestBodyBytes),
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
  log.info('[worker-$workerId] Stopped.');
}

/// Returns a [RawReceivePort] that logs uncaught isolate errors without
/// terminating the process.
RawReceivePort _isolateErrorPort(int workerId, Logger log) {
  return RawReceivePort((dynamic error) {
    log.severe('[worker-$workerId] Uncaught error: $error');
    // TODO: restart isolate or trigger alerting.
  });
}
