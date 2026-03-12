import 'package:dart_backend_architecture/core/response/shelf_response_x.dart';
import 'package:dart_backend_architecture/helpers/validator.dart';
import 'package:dart_backend_architecture/routes/v1/access/schema.dart';
import 'package:dart_backend_architecture/services/auth_service.dart';
import 'package:shelf/shelf.dart';

Future<Response> logoutHandler(
  Request request,
  AuthService authService,
) async {
  final headerValidated = validateSchema(
    authHeaderSchema,
    {'authorization': request.headers['authorization']},
    source: ValidationSource.header,
  );
  final accessToken =
      validateAuthBearer(headerValidated['authorization'] as String);
  await authService.logout(accessToken);
  return ok<Object?>(message: 'Logout success');
}
