import 'package:dart_backend_architecture/core/response/shelf_response_x.dart';
import 'package:dart_backend_architecture/routes/v1/access/schema.dart';
import 'package:dart_backend_architecture/helpers/validator.dart';
import 'package:dart_backend_architecture/services/auth_service.dart';
import 'package:shelf/shelf.dart';

Future<Response> loginHandler(
  Request request,
  AuthService authService,
) async {
  final decoded = await readJsonBody(request);
  final validated = validateSchema(userCredentialSchema, decoded);

  final dto = LoginDto.fromJson(validated);
  final auth = await authService.login(dto);

  return ok(
    message: 'Login successful',
    data: auth.toJson(),
  );
}
