import 'dart:convert';

import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/routes/base_response.dart';
import 'package:dart_backend_architecture/routes/v1/access/access_schema.dart';
import 'package:dart_backend_architecture/services/auth_service.dart';
import 'package:shelf/shelf.dart';

Future<Response> loginHandler(
  Request request,
  AuthService authService,
) async {
  final raw = await request.readAsString();
  final decoded = jsonDecode(raw);

  if (decoded is! Map<String, dynamic>) {
    throw const BadRequestError('Invalid request body');
  }

  final result = userCredentialSchema.safeParse(decoded);
  if (result.isFailure) {
    throw ValidationError({'body': result.errors.map((e) => e.message).toList(growable: false)});
  }

  final dto = LoginDto.fromJson(result.value);
  final auth = await authService.login(dto);

  return ok(
    message: 'Login successful',
    data: auth.toJson(),
  );
}
