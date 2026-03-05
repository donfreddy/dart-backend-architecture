import 'package:dart_backend_architecture/core/validation/validator.dart';
import 'package:dart_backend_architecture/routes/base_response.dart';
import 'package:dart_backend_architecture/routes/v1/access/schema.dart';
import 'package:dart_backend_architecture/services/auth_service.dart';
import 'package:shelf/shelf.dart';

Future<Response> signupHandler(
  Request request,
  AuthService authService,
) async {
  final decoded = await readJsonBody(request);
  final validated = validateSchema(signupSchema, decoded);

  final dto = SignupDto.fromJson(validated);
  final auth = await authService.signup(dto);

  return ok(
    message: 'Signup Successful',
    data: auth.toJson(),
  );
}
