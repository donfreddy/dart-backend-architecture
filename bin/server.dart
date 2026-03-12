import 'dart:io';
import 'dart:isolate';

import 'package:dart_backend_architecture/app.dart';
import 'package:dart_backend_architecture/config.dart';
import 'package:dart_backend_architecture/core/logger.dart';
import 'package:dart_backend_architecture/core/telemetry/otel_setup.dart';
import 'package:dart_backend_architecture/di/composition_root.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

Future<void> main() async {
  // Structured JSON logs — must be first
  AppLogger.configure();

  // OpenTelemetry — before any request is served
  await initTelemetry();

  final config = AppConfig.fromEnv();
  final count = config.workerCount > 0 ? config.workerCount : Platform.numberOfProcessors;
  AppLogger.root.info('Starting $count isolate(s) on port ${config.port}');

  // Spawn N-1 worker isolates — main isolate handles its own share
  for (var i = 1; i < count; i++) {
    await Isolate.spawn(
      _spawnServer,
      i,
      debugName: 'worker-$i',
      onError: _isolateErrorPort.sendPort,
    );
  }

  // Main isolate also serves traffic
  await _spawnServer(0);
}

// ── Isolate error handler ─────────────────────────────────────

final _isolateErrorPort = RawReceivePort((dynamic error) {
  AppLogger.root.severe('Isolate crashed: $error');
  // In production, consider restarting the isolate or alerting
});

// ── Server bootstrap (runs in each isolate) ───────────────────

Future<void> _spawnServer(int workerId) async {
  final log = AppLogger.get('worker-$workerId');

  try {
    final config = AppConfig.fromEnv();
    final root = await CompositionRoot.initialize(config);

    final server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      config.port,
      shared: true, // All isolates share the same TCP socket
    );

    server.autoCompress = true;
    server.idleTimeout = const Duration(seconds: 30);

    shelf_io.serveRequests(
      server,
      buildApp(
        root.router,
        maxRequestBodyBytes: config.maxRequestBodyBytes,
      ),
    );
    log.info('Listening on :${server.port}');

    // ── Graceful shutdown ─────────────────────────────────────
    // SIGTERM is sent by Docker / Kubernetes on container stop
    await _handleShutdown(
      server: server,
      root: root,
      log: log,
    );
  } catch (e, st) {
    log.severe('Failed to start server', e, st);
    exit(1);
  }
}

// ── Graceful shutdown ─────────────────────────────────────────

Future<void> _handleShutdown({
  required HttpServer server,
  required CompositionRoot root,
  required Logger log,
}) async {
  final signals = [
    ProcessSignal.sigterm,
    ProcessSignal.sigint, // Ctrl+C in local dev
  ];

  await Future.any(
    signals.map((s) => s.watch().first),
  );

  log.info('Shutdown signal received — draining connections...');

  // Stop accepting new connections, wait for in-flight requests
  await server.close(force: false).timeout(
    const Duration(seconds: 15),
    onTimeout: () {
      log.warning('Drain timeout — forcing shutdown');
      return server.close(force: true);
    },
  );

  // Release infrastructure resources
  await root.dispose();

  log.info('Shutdown complete');
  exit(0);
}
