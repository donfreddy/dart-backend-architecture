import 'dart:convert';

import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/routes/base_response.dart';
import 'package:dart_backend_architecture/routes/v1/access/access_schema.dart';
import 'package:dart_backend_architecture/services/auth_service.dart';
import 'package:shelf/shelf.dart';

Future<Response> tokenHandler(
  Request request,
  AuthService authService,
) async {
  final headerValidation = authHeaderSchema.safeParse({
    'authorization': request.headers['authorization'],
  });
  if (headerValidation.isFailure) {
    throw ValidationError({
      'authorization': headerValidation.errors.map((e) => e.message).toList(growable: false),
    });
  }

  final accessToken = _extractBearerToken(request);

  final raw = await request.readAsString();
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw const BadRequestError('Invalid request body');
  }

  final bodyValidation = refreshTokenSchema.safeParse(decoded);
  if (bodyValidation.isFailure) {
    throw ValidationError({
      'body': bodyValidation.errors.map((e) => e.message).toList(growable: false),
    });
  }

  final refreshToken = bodyValidation.value['refreshToken'] as String;
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
