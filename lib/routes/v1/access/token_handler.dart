import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/core/response/shelf_response_x.dart';
import 'package:dart_backend_architecture/helpers/validator.dart';
import 'package:dart_backend_architecture/routes/v1/access/schema.dart';
import 'package:dart_backend_architecture/services/auth_service.dart';
import 'package:shelf/shelf.dart';

Future<Response> tokenHandler(
  Request request,
  AuthService authService,
) async {
  final rawAuth = request.headers['authorization'];
  if (rawAuth == null || rawAuth.isEmpty) {
    throw const AuthFailureError('Missing authorization header');
  }

  final accessToken = validateAuthBearer(rawAuth);

  final decoded = await readJsonBody(request);
  final bodyValidated = validateSchema(refreshTokenSchema, decoded);
  final refreshToken = bodyValidated['refresh_token'] as String;
  final tokens = await authService.refreshToken(
    accessToken: accessToken,
    refreshToken: refreshToken,
  );

  return ok(
    message: 'Token Issued',
    data: {
      'access_token': tokens.accessToken,
      'refresh_token': tokens.refreshToken,
    },
  );
}
