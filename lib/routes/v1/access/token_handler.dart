import 'package:dart_backend_architecture/helpers/validator.dart';
import 'package:dart_backend_architecture/routes/base_response.dart';
import 'package:dart_backend_architecture/routes/v1/access/schema.dart';
import 'package:dart_backend_architecture/services/auth_service.dart';
import 'package:shelf/shelf.dart';

Future<Response> tokenHandler(
  Request request,
  AuthService authService,
) async {
  final headerValidated = validateSchema(
    authHeaderSchema,
    {
      'authorization': request.headers['authorization'],
    },
    source: ValidationSource.header,
  );
  final accessToken = validateAuthBearer(headerValidated['authorization'] as String);

  final decoded = await readJsonBody(request);
  final bodyValidated = validateSchema(
    refreshTokenSchema,
    decoded,
    source: ValidationSource.body,
  );
  final refreshToken = bodyValidated['refreshToken'] as String;
  final tokens = await authService.refreshToken(
    accessToken: accessToken,
    refreshToken: refreshToken,
  );

  return ok(
    message: 'Token Issued',
    data: {
      'accessToken': tokens.accessToken,
      'refreshToken': tokens.refreshToken,
    },
  );
}
