import 'dart:async';
import 'package:dart_backend_architecture/core/response/api_response.dart';
import 'package:dart_backend_architecture/core/response/shelf_response_x.dart';
import 'package:dart_backend_architecture/core/logger.dart';
import 'package:shelf/shelf.dart';

final _log = AppLogger.get('health');
final _startedAt = DateTime.now().toUtc();

typedef Probe = Future<bool> Function();

Future<Response> healthzHandler(Request _) async {
  return ok(
    message: 'ok',
    data: {
      'status': 'live',
      'startedAt': _startedAt.toIso8601String(),
    },
  );
}

Future<Response> readyzHandler({
  required Probe dbCheck,
  required Probe cacheCheck,
  required Probe natsCheck,
  Duration timeout = const Duration(seconds: 2),
}) async {
  final results = await Future.wait([
    _run('database', dbCheck, timeout),
    _run('cache', cacheCheck, timeout),
    _run('nats', natsCheck, timeout),
  ]);

  final allHealthy = results.every((r) => r.ok);

  return ok(
    statusCode: allHealthy ? StatusCode.success : StatusCode.failure,
    message: allHealthy ? 'ready' : 'degraded',
    data: {
      for (final r in results)
        r.name: {
          'ok': r.ok,
          if (r.error != null) 'error': r.error,
          'durationMs': r.durationMs,
        },
    },
  );
}

Future<_ProbeResult> _run(String name, Probe probe, Duration timeout) async {
  final started = DateTime.now().microsecondsSinceEpoch;
  try {
    final ok = await probe().timeout(timeout);
    final duration = (DateTime.now().microsecondsSinceEpoch - started) ~/ 1000;
    return _ProbeResult(name, ok: ok, durationMs: duration);
  } catch (e, st) {
    _log.warning('Health probe failed for $name', e, st);
    final duration = (DateTime.now().microsecondsSinceEpoch - started) ~/ 1000;
    return _ProbeResult(name, ok: false, error: e.toString(), durationMs: duration);
  }
}

final class _ProbeResult {
  final String name;
  final bool ok;
  final String? error;
  final int durationMs;

  const _ProbeResult(this.name, {required this.ok, this.error, required this.durationMs});
}
