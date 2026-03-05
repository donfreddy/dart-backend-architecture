import 'package:dart_backend_architecture/core/middleware/api_key_middleware.dart';
import 'package:dart_backend_architecture/core/middleware/cors_middleware.dart';
import 'package:dart_backend_architecture/core/middleware/error_handler_middleware.dart';
import 'package:dart_backend_architecture/core/middleware/rate_limit_middleware.dart';
import 'package:dart_backend_architecture/core/middleware/tracing_middleware.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/api_key_repo.dart';
import 'package:shelf/shelf.dart';

Handler buildApp(
  Handler router, {
  List<String> corsAllowedOrigins = const [],
  ApiKeyRepo? apiKeyRepo,
  RateLimitStore? rateLimitStore,
  int rateLimitMaxRequests = 100,
  Duration rateLimitWindow = const Duration(minutes: 1),
}) {
  var pipeline = const Pipeline()
      // ── Error boundary (outermost) ───────────────────────
      .addMiddleware(errorHandlerMiddleware())

      // ── Observability ─────────────────────────────────────
      .addMiddleware(tracingMiddleware())
      .addMiddleware(logRequests())

      // ── Security baseline ─────────────────────────────────
      .addMiddleware(
        corsMiddleware(
          allowedOrigins: corsAllowedOrigins,
        ),
      );

  if (apiKeyRepo != null) {
    pipeline = pipeline.addMiddleware(apiKeyMiddleware(apiKeyRepo));
  }

  if (rateLimitStore != null) {
    pipeline = pipeline.addMiddleware(
      rateLimitMiddleware(
        rateLimitStore,
        maxRequests: rateLimitMaxRequests,
        window: rateLimitWindow,
      ),
    );
  }

  return pipeline.addHandler(router);
}
