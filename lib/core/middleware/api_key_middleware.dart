import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/core/logger.dart';
import 'package:dart_backend_architecture/core/middleware/schema.dart';
import 'package:dart_backend_architecture/core/request_context_keys.dart';
import 'package:dart_backend_architecture/helpers/validator.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/api_key_repo.dart';
import 'package:shelf/shelf.dart';

const _apiKeyHeader = 'x-api-key';

final _log = AppLogger.get('ApiKeyMiddleware');

Middleware apiKeyMiddleware(ApiKeyRepo apiKeyRepo) {
  return (Handler inner) {
    return (Request request) async {
      // Skip preflight CORS requests
      if (request.method == 'OPTIONS') return inner(request);

      final rawKey = request.headers[_apiKeyHeader];
      if (rawKey == null || rawKey.isEmpty) {
        throw const ForbiddenError('Missing x-api-key header');
      }

      final headerValidated = validateSchema(
        apiKeyHeaderSchema,
        {_apiKeyHeader: rawKey},
        source: ValidationSource.header,
      );
      final apiKey = headerValidated[_apiKeyHeader] as String;
      final keyEntity = await apiKeyRepo.findByKey(apiKey);
      _log.info('API key lookup result: ${keyEntity != null}');

      if (keyEntity == null) {
        throw const ForbiddenError();
      }

      final enrichedRequest = request.change(
        context: {
          ...request.context,
          RequestContextKeys.apiKey: apiKey,
        },
      );

      return inner(enrichedRequest);
    };
  };
}
