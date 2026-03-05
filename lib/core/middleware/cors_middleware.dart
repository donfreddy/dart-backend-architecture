// lib/core/middleware/cors_middleware.dart
import 'package:shelf/shelf.dart';

Middleware corsMiddleware({
  List<String> allowedOrigins = const [],
  List<String> allowedMethods = const ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  List<String> allowedHeaders = const ['Content-Type', 'Authorization', 'x-api-key'],
  List<String> exposedHeaders = const ['instruction', 'X-RateLimit-Limit', 'X-RateLimit-Remaining'],
  bool allowCredentials = true,
  Duration maxAge = const Duration(hours: 24),
}) {
  final normalizedOrigins = allowedOrigins.map((o) => o.trim()).where((o) => o.isNotEmpty).toSet();
  final allowsAnyOrigin = normalizedOrigins.contains('*');

  return (Handler inner) {
    return (Request request) async {
      final origin = request.headers['origin'];
      final hasOrigin = origin != null && origin.isNotEmpty;

      final isAllowed =
          !hasOrigin || normalizedOrigins.isEmpty || allowsAnyOrigin || normalizedOrigins.contains(origin);

      final corsHeaders = <String, String>{
        if (hasOrigin && isAllowed) 'Access-Control-Allow-Origin': origin,
        'Access-Control-Allow-Methods': allowedMethods.join(', '),
        'Access-Control-Allow-Headers': allowedHeaders.join(', '),
        if (exposedHeaders.isNotEmpty) 'Access-Control-Expose-Headers': exposedHeaders.join(', '),
        if (allowCredentials) 'Access-Control-Allow-Credentials': 'true',
        'Access-Control-Max-Age': maxAge.inSeconds.toString(),
        'Vary': 'Origin',
      };

      // Preflight — return immediately without hitting handlers
      if (request.method == 'OPTIONS') {
        if (hasOrigin && !isAllowed) {
          return Response.forbidden('CORS origin not allowed');
        }
        return Response(204, headers: corsHeaders);
      }

      final response = await inner(request);
      if (!hasOrigin || !isAllowed) {
        return response;
      }
      return response.change(
        headers: {
          ...response.headers,
          ...corsHeaders,
        },
      );
    };
  };
}
