import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/core/logger.dart';
import 'package:dart_backend_architecture/core/response/api_response.dart';
import 'package:dart_backend_architecture/core/response/shelf_response_x.dart';
import 'package:dart_backend_architecture/core/app_info.dart';
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:shelf/shelf.dart';

final _log = AppLogger.get('ErrorHandler');

// OTel SDK caches instruments by name, calling createCounter each time is idempotent.
final Counter<int> _errorCounter =
    OTel.meterProvider().getMeter(name: AppInfo.name).createCounter<int>(
          name: 'api.errors.total',
          description: 'Total API errors by type and HTTP status',
          unit: '{error}',
        ) as Counter<int>;

void _recordError(ApiError error) {
  try {
    _errorCounter.add(
      1,
      OTel.attributesFromMap({
        'error.type': error.code,
        'http.status_code': error.type.httpStatus,
      }),
    );
  } catch (_) {}
}

Middleware errorHandlerMiddleware() {
  return (Handler inner) {
    return (Request request) async {
      try {
        return await inner(request);
      } on ApiError catch (e) {
        return _handleApiError(request, e);
      } on FormatException catch (e) {
        final error = BadRequestError('Malformed request: ${e.message}');
        return _handleApiError(request, error);
      } catch (e, st) {
        _log.severe(
          'Unhandled exception on ${request.method} ${request.url.path}',
          e,
          st,
        );
        return _handleApiError(
          request,
          const InternalError('An unexpected error occurred'),
        );
      }
    };
  };
}

Response _handleApiError(Request request, ApiError error) {
  _recordError(error);

  final status = error.type.httpStatus;
  if (status >= 500) {
    _log.severe(
      'HTTP ${request.method} ${request.requestedUri.path} -> ${error.code}: ${error.message}',
    );
  } else {
    _log.warning(
      'HTTP ${request.method} ${request.requestedUri.path} -> ${error.code}: ${error.message}',
    );
  }

  return Failure(error: error).toShelfResponse();
}
