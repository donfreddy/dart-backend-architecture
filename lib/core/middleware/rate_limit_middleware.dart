import 'dart:convert';

import 'package:dart_backend_architecture/core/logger.dart';
import 'package:dart_backend_architecture/core/app_info.dart';
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:shelf/shelf.dart';

final _log = AppLogger.get('RateLimit');

// The OTel SDK caches instruments by name so calling createCounter() on every
// bypass is idempotent and effectively free, no manual caching needed.
// Wrapped in try/catch so a disabled or uninitialised OTel stack never
// blocks an HTTP request.
void _incrementBypassCounter() {
  try {
    OTel.meterProvider()
        .getMeter(name: AppInfo.name)
        .createCounter<int>(
          name: 'rate_limit.bypass.total',
          description:
              'Requests that bypassed rate limiting due to store unavailability',
          unit: '{request}',
        )
        .add(1);
  } catch (_) {}
}

// Default: 100 requests per minute per IP
const _defaultMaxRequests = 100;
const _defaultWindow = Duration(minutes: 1);

/// Stricter limits for sensitive endpoints (signup, login, token refresh).
const _sensitiveWindow = Duration(minutes: 1);

abstract interface class RateLimitStore {
  Future<int> increment(String key, {required Duration window});
}

/// Rate-limit middleware with optional endpoint-specific overrides.
///
/// When [endpointOverrides] is provided, the request path is matched (prefix)
/// against the keys. If matched, the override [maxRequests] and [window] are
/// used and the Redis key is scoped to avoid interference with the global limit.
///
/// Example — limit signup to 10 req/min per IP:
/// ```dart
/// rateLimitMiddleware(store, endpointOverrides: {
///   '/signup': (maxRequests: 10),
/// });
/// ```
Middleware rateLimitMiddleware(
  RateLimitStore store, {
  int maxRequests = _defaultMaxRequests,
  Duration window = _defaultWindow,
  Map<String, ({int maxRequests})> endpointOverrides = const {},
}) {
  return (Handler inner) {
    return (Request request) async {
      final ip = _extractIp(request);
      final path = request.url.path;

      // Check endpoint-specific overrides first
      final override = _matchOverride(path, endpointOverrides);
      final effectiveMax =
          override != null ? override.maxRequests : maxRequests;
      final effectiveWindow = override != null ? _sensitiveWindow : window;
      final prefix = override != null ? 'sensitive_rate_limit' : 'rate_limit';
      final key = '$prefix:$path:$ip';

      try {
        final current = await store.increment(key, window: effectiveWindow);

        if (current > effectiveMax) {
          _log.warning(
            'Rate limit exceeded for IP: $ip on $path ($current/$effectiveMax)',
          );
          return Response(
            429,
            body: jsonEncode({
              'message': 'Too many requests — please try again later',
              'data': {'code': 'RATE_LIMIT_EXCEEDED'},
            }),
            headers: {
              'content-type': 'application/json',
              'Retry-After': effectiveWindow.inSeconds.toString(),
              'X-RateLimit-Limit': effectiveMax.toString(),
              'X-RateLimit-Remaining': '0',
            },
          );
        }

        final response = await inner(request);

        return response.change(
          headers: {
            'X-RateLimit-Limit': effectiveMax.toString(),
            'X-RateLimit-Remaining':
                (effectiveMax - current).clamp(0, effectiveMax).toString(),
          },
        );
      } catch (e) {
        _incrementBypassCounter();
        _log.severe(
          'RATE_LIMIT_BYPASS: Redis unavailable, skipping rate limit for IP $ip — $e',
        );
        return inner(request);
      }
    };
  };
}

/// Returns the first matching override whose key is a prefix of [path].
({int maxRequests})? _matchOverride(
  String path,
  Map<String, ({int maxRequests})> overrides,
) {
  for (final entry in overrides.entries) {
    if (path.startsWith(entry.key)) return entry.value;
  }
  return null;
}

String _extractIp(Request request) {
  // Respect reverse proxy headers (nginx, load balancer)
  final forwarded = request.headers['x-forwarded-for'];
  if (forwarded != null && forwarded.isNotEmpty) {
    return forwarded.split(',').first.trim();
  }

  final realIp = request.headers['x-real-ip'];
  if (realIp != null && realIp.isNotEmpty) return realIp;

  final connectionInfo = request.context['shelf.io.connection_info'];
  if (connectionInfo != null) return connectionInfo.toString();

  return 'unknown';
}
