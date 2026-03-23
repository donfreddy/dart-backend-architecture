import 'dart:io';

import 'package:dart_backend_architecture/config.dart';
import 'package:dart_backend_architecture/core/app_info.dart';
import 'package:dart_backend_architecture/core/logger.dart';
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

final _log = AppLogger.get('otel');

Future<void> initTelemetry() async {
  final config = AppConfig.fromEnv();

  // Skip if no endpoint configured — local dev without collector
  if (config.otelEndpoint.isEmpty) {
    _log.info('OTEL_ENDPOINT not set — telemetry disabled');
    return;
  }

  try {
    final endpoint = config.otelEndpoint;
    final secure = endpoint.startsWith('https://');

    await OTel.initialize(
      endpoint: endpoint,
      secure: secure,
      serviceName: AppInfo.name,
      serviceVersion: AppInfo.version,
      resourceAttributes: {
        'deployment.environment': config.environment,
        'service.namespace': AppInfo.namespace,
        'host.name': _hostname(),
      }.toAttributes(),
    );

    _log.info('OpenTelemetry initialized → ${config.otelEndpoint}');
  } catch (e, st) {
    // Telemetry failure must never crash the server
    _log.warning(
      'OpenTelemetry initialization failed — continuing without it',
      e,
      st,
    );
  }
}

Future<void> shutdownTelemetry() async {
  try {
    await OTel.shutdown();
  } catch (_) {}
}

String _hostname() {
  try {
    return Platform.localHostname;
  } catch (_) {
    return 'unknown';
  }
}
