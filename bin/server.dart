import 'dart:async';
import 'dart:io';

import 'package:dart_backend_architecture/app.dart';
import 'package:dart_backend_architecture/config.dart';
import 'package:dart_backend_architecture/core/logger.dart';
import 'package:dart_backend_architecture/core/telemetry/otel_setup.dart'
    show initTelemetry, shutdownTelemetry;
import 'package:dart_backend_architecture/di/composition_root.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

Future<void> main() async {
  AppLogger.configure();
  await initTelemetry();

  final config = AppConfig.fromEnv();
  final log = AppLogger.get('main');

  log.info('Starting server on port ${config.port}');

  final server = await _bindServer(config);
  final root = await CompositionRoot.initialize(config);

  shelf_io.serveRequests(
    server,
    buildApp(
      root.router,
      maxRequestBodyBytes: config.maxRequestBodyBytes,
      apiKeyRepo: root.apiKeyRepo,
      rateLimitStore: root.rateLimitStore,
    ),
  );

  log.info('Listening on :${server.port}');

  await Future.any([
    ProcessSignal.sigterm.watch().first,
    ProcessSignal.sigint.watch().first,
  ]);

  log.info('Shutdown signal received — draining...');

  await _gracefulStop(server: server, root: root, log: log);

  log.info('Server stopped.');
  exit(0);
}

Future<HttpServer> _bindServer(AppConfig config) async {
  final server = await HttpServer.bind(
    InternetAddress.anyIPv4,
    config.port,
  );
  server.autoCompress = true;
  server.idleTimeout = const Duration(seconds: 30);
  return server;
}

Future<void> _gracefulStop({
  required HttpServer server,
  required CompositionRoot root,
  required Logger log,
}) async {
  log.info('Draining...');

  await server.close(force: false).timeout(
    const Duration(seconds: 15),
    onTimeout: () {
      log.warning('Drain timeout — forcing close');
      return server.close(force: true);
    },
  );

  await root.dispose();
  await shutdownTelemetry();
  log.info('Stopped.');
}
