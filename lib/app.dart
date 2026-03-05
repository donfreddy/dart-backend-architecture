import 'package:dart_backend_architecture/core/middleware/api_key_middleware.dart';
import 'package:dart_backend_architecture/core/middleware/auth_middleware.dart';
import 'package:dart_backend_architecture/core/middleware/cors_middleware.dart';
import 'package:dart_backend_architecture/core/middleware/error_handler_middleware.dart';
import 'package:dart_backend_architecture/core/middleware/rate_limit_middleware.dart';
import 'package:dart_backend_architecture/core/middleware/tracing_middleware.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';

Handler buildApp(Handler router) {
  return const Pipeline()
      // ── Observability ─────────────────────────────────────
      // First — captures every request including those that fail auth
      .addMiddleware(tracingMiddleware())
      .addMiddleware(logRequests())

      // ── Security ──────────────────────────────────────────
      .addMiddleware(corsMiddleware())
      .addMiddleware(apiKeyMiddleware())
      .addMiddleware(rateLimitMiddleware())

      // ── Error boundary ────────────────────────────────────
      // Last — catches everything thrown by middleware below and handlers
      .addMiddleware(errorHandlerMiddleware())

      // ── Business ──────────────────────────────────────────
      .addHandler(router);
}
