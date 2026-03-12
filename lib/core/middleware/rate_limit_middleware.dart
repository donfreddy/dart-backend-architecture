import 'dart:convert';

import 'package:dart_backend_architecture/core/response/api_response.dart';
import 'package:dart_backend_architecture/core/logger.dart';
import 'package:shelf/shelf.dart';

final _log = AppLogger.get('RateLimit');

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
              'Rate limit exceeded for IP: $ip ($current/$maxRequests)');
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
        // Redis failure must never block a request
        _log.warning('Rate limit check failed — bypassing: $e');
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
