import 'dart:convert';

import 'package:dart_backend_architecture/core/response/api_response.dart';
import 'package:dart_backend_architecture/core/logger.dart';
import 'package:dart_backend_architecture/core/app_info.dart';
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:shelf/shelf.dart';

final _log = AppLogger.get('RateLimit');

// The OTel SDK caches instruments by name so calling createCounter() on every
// bypass is idempotent and effectively free — no manual caching needed.
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

abstract interface class RateLimitStore {
  Future<int> increment(String key, {required Duration window});
}

Middleware rateLimitMiddleware(
  RateLimitStore store, {
  int maxRequests = _defaultMaxRequests,
  Duration window = _defaultWindow,
}) {
  return (Handler inner) {
    return (Request request) async {
      final ip = _extractIp(request);
      final key = 'rate_limit:$ip';

      try {
        final current = await store.increment(key, window: window);

        if (current > maxRequests) {
          _log.warning(
            'Rate limit exceeded for IP: $ip ($current/$maxRequests)',
          );
          return Response(
            429,
            body: jsonEncode({
              'status': StatusCode.failure.value,
              'message': 'Too many requests — please try again later',
              'data': {'code': 'RATE_LIMIT_EXCEEDED'},
            }),
            headers: {
              'content-type': 'application/json',
              'Retry-After': window.inSeconds.toString(),
              'X-RateLimit-Limit': maxRequests.toString(),
              'X-RateLimit-Remaining': '0',
            },
          );
        }

        final response = await inner(request);

        // Inject rate limit headers on every response
        return response.change(
          headers: {
            'X-RateLimit-Limit': maxRequests.toString(),
            'X-RateLimit-Remaining':
                (maxRequests - current).clamp(0, maxRequests).toString(),
          },
        );
      } catch (e) {
        // Redis failure must never block a request, but we log at SEVERE so
        // that alerting rules (log-based metrics, PagerDuty, etc.) can fire.
        // Tag: RATE_LIMIT_BYPASS — use this string in alert filter queries.
        _incrementBypassCounter();
        _log.severe(
          'RATE_LIMIT_BYPASS: Redis unavailable, skipping rate limit for IP $ip — $e',
        );
        return inner(request);
      }
    };
  };
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
