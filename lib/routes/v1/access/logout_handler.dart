import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/routes/base_response.dart';
import 'package:dart_backend_architecture/services/auth_service.dart';
import 'package:shelf/shelf.dart';

Future<Response> logoutHandler(
  Request request,
  AuthService authService,
) async {
  final accessToken = _extractBearerToken(request);
  await authService.logout(accessToken);
  return ok<Object?>(message: 'Logout success');
}

String _extractBearerToken(Request request) {
  final authorization = request.headers['authorization'];
  if (authorization == null || authorization.isEmpty) {
    throw const ValidationError({
      'authorization': ['Missing Authorization header'],
    });
  }

  final parts = authorization.split(' ');
  if (parts.length != 2 || parts.first.toLowerCase() != 'bearer' || parts.last.isEmpty) {
    throw const ValidationError({
      'authorization': ['Invalid bearer token format'],
    });
  }

  return parts.last;
}
