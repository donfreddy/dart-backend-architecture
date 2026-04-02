import 'package:dart_backend_architecture/core/logger.dart';
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:shelf/shelf.dart';

final _log = AppLogger.get('Tracing');

Middleware tracingMiddleware() {
  return (Handler inner) {
    return (Request request) async {
      late final Tracer tracer;
      try {
        tracer = OTel.tracerProvider().getTracer('http.server');
      } on StateError {
        // OTel not initialized: keep request path fast and skip tracing.
        return inner(request);
      } catch (e, st) {
        //_log.warning('Unable to initialize tracer for request', e, st);
        if (e is! StateError && e is! TypeError) {
          _log.warning('Unable to initialize tracer for request', e, st);
        }
        return inner(request);
      }

      final start = DateTime.now().microsecondsSinceEpoch;

      final span = tracer.startSpan(
        '${request.method} ${request.url.path}',
        kind: SpanKind.server,
        attributes: OTel.attributesFromMap({
          'http.method': request.method,
          'http.url': request.requestedUri.toString(),
          'http.target': request.url.path,
          'http.host': request.headers['host'] ?? '',
          'http.scheme': request.requestedUri.scheme,
        }),
      );

      try {
        final response = await inner(request);

        span
          ..addAttributes(
            OTel.attributesFromMap({
              'http.status_code': response.statusCode,
              'http.server_duration_ms':
                  (DateTime.now().microsecondsSinceEpoch - start) / 1000.0,
            }),
          )
          ..setStatus(
            response.statusCode < 400
                ? SpanStatusCode.Ok
                : SpanStatusCode.Error,
          );

        return response;
      } catch (e, st) {
        span
          ..recordException(e, stackTrace: st)
          ..setStatus(SpanStatusCode.Error, e.toString());
        rethrow;
      } finally {
        span.end();
      }
    };
  };
}
