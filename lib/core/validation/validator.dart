import 'dart:convert';

import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/core/logger.dart';
import 'package:shelf/shelf.dart';
import 'package:zema/zema.dart';

enum ValidationSource {
  body,
  header,
  query,
  param,
}

final _log = AppLogger.get('Validator');

// extension ZemaCustomValidators on ZemaString {
//   ZemaSchema<String, String> bearer() =>
//       transform((v) {
//         if (!v.startsWith('Bearer ')) throw 'Missing Bearer prefix';
//         final token = v.substring(7).trim();
//         if (token.isEmpty) throw 'Empty token';
//         return token;
//       });
// }

Map<String, dynamic> validateSchema<O extends Map<String, dynamic>>(
  ZemaSchema<dynamic, O> schema,
  Map<String, dynamic> input, {
  ValidationSource source = ValidationSource.body,
}) {
  final result = schema.safeParse(input);

  if (result.isFailure) {
    final message = result.errors.map((ZemaIssue e) => e.message).join(', ');
    _log.warning('Validation failed [${source.name}]: $message');
    throw BadRequestError(message);
  }

  return result.value;
}

Future<Map<String, dynamic>> readJsonBody(Request request) async {
  final raw = await request.readAsString();
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw const BadRequestError('Invalid request body');
  }
  return decoded;
}

String validateUrlEndpoint(String value) {
  if (value.contains('://')) {
    throw const BadRequestError('Invalid url endpoint');
  }
  return value;
}

String validateAuthBearer(String value) {
  if (!value.startsWith('Bearer ')) {
    throw const BadRequestError('Invalid authorization header');
  }

  final token = value.substring(7).trim();
  if (token.isEmpty) {
    throw const BadRequestError('Invalid authorization header');
  }

  return token;
}
