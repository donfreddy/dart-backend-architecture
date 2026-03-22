import 'package:dart_backend_architecture/core/middleware/api_key_middleware.dart';
import 'package:dart_backend_architecture/core/middleware/body_limit_middleware.dart';
import 'package:dart_backend_architecture/core/middleware/cors_middleware.dart';
import 'package:dart_backend_architecture/core/middleware/error_handler_middleware.dart';
import 'package:dart_backend_architecture/core/middleware/rate_limit_middleware.dart';
import 'package:dart_backend_architecture/core/middleware/security_headers_middleware.dart';
import 'package:dart_backend_architecture/core/middleware/tracing_middleware.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/api_key_repo.dart';
import 'package:shelf/shelf.dart';

/// Builds the top-level Shelf pipeline used by the server.
///
/// Pipeline order (outermost → innermost):
///   errorHandler → tracing → logging → bodyLimit → securityHeaders
///   → [rateLimit] → cors → [apiKey] → router
///
/// Key ordering decisions:
/// - [securityHeadersMiddleware] is before rateLimit so headers appear on 429s.
/// - [rateLimitMiddleware] is before [corsMiddleware] so OPTIONS preflight
///   requests are also rate-limited (prevents preflight flooding bypass).
/// - [apiKeyMiddleware] is after cors because preflight is already handled.
Handler buildApp(
  Handler router, {
  List<String> corsAllowedOrigins = const [],
  ApiKeyRepo? apiKeyRepo,
  RateLimitStore? rateLimitStore,
  int rateLimitMaxRequests = 100,
  Duration rateLimitWindow = const Duration(minutes: 1),
  int maxRequestBodyBytes = 1024 * 1024,
}) {
  var pipeline = const Pipeline()
      // ── Error boundary (outermost) ───────────────────────
      .addMiddleware(errorHandlerMiddleware())

      // ── Observability ─────────────────────────────────────
      .addMiddleware(tracingMiddleware())
      .addMiddleware(logRequests())

      // ── Request hygiene ───────────────────────────────────
      .addMiddleware(bodyLimitMiddleware(maxBytes: maxRequestBodyBytes))

      // ── Security headers (on every response, including errors) ────────────
      .addMiddleware(securityHeadersMiddleware());

  // ── Rate limiting (before CORS so preflight is also covered) ─────────────
  if (rateLimitStore != null) {
    pipeline = pipeline.addMiddleware(
      rateLimitMiddleware(
        rateLimitStore,
        maxRequests: rateLimitMaxRequests,
        window: rateLimitWindow,
      ),
    );
  }

  // ── CORS (handles OPTIONS preflight after rate limiting) ──────────────────
  pipeline = pipeline.addMiddleware(
    corsMiddleware(allowedOrigins: corsAllowedOrigins),
  );

  // ── API key validation (skips OPTIONS internally) ─────────────────────────
  if (apiKeyRepo != null) {
    pipeline = pipeline.addMiddleware(apiKeyMiddleware(apiKeyRepo));
  }

  return pipeline.addHandler(router);
}
