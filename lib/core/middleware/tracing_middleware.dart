import 'package:dart_backend_architecture/core/app_info.dart';
import 'package:dart_backend_architecture/core/logger.dart';
import 'package:dart_backend_architecture/core/request_context_keys.dart';
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:shelf/shelf.dart';

final _log = AppLogger.get('Tracing');

Counter<int>? _requestCounter;
Histogram? _durationHistogram;

Middleware tracingMiddleware() {
  return (Handler inner) {
    return (Request request) async {
      late final Tracer tracer;
      try {
        tracer = OTel.tracerProvider().getTracer('http.server');
        _requestCounter ??= OTel.meterProvider()
            .getMeter(name: AppInfo.name)
            .createCounter<int>(
              name: 'http.requests.total',
              description: 'Total HTTP requests',
              unit: '{request}',
            ) as Counter<int>?;
        _durationHistogram ??= OTel.meterProvider()
            .getMeter(name: AppInfo.name)
            .createHistogram<double>(
              name: 'http.server.duration_ms',
              description: 'HTTP request duration in milliseconds',
              unit: 'ms',
            ) as Histogram?;
      } on StateError {
        return inner(request);
      } catch (e, st) {
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
        final response = await inner(
          request.change(
            context: {
              ...request.context,
              RequestContextKeys.otelSpan: span,
            },
          ),
        );

        final durationMs =
            (DateTime.now().microsecondsSinceEpoch - start) / 1000.0;

        span
          ..addAttributes(
            OTel.attributesFromMap({
              'http.status_code': response.statusCode,
              'http.server_duration_ms': durationMs,
            }),
          )
          ..setStatus(
            response.statusCode < 400
                ? SpanStatusCode.Ok
                : SpanStatusCode.Error,
          );

        _requestCounter?.add(
          1,
          OTel.attributesFromMap({
            'http.method': request.method,
            'http.status_code': response.statusCode,
          }),
        );
        _durationHistogram?.record(
          durationMs,
          OTel.attributesFromMap({
            'http.method': request.method,
            'http.status_code': response.statusCode,
          }),
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
