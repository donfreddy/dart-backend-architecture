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

// ─── Schemas ─────────────────────────────────────────────────────────────────

// final _urlEndpointSchema = z.string().refine(
//       (v) => !v.contains('://'),
//       message: 'Invalid url endpoint',
//     );

// final _bearerSchema = z
//     .string()
//     .refine(
//       (v) => v.startsWith('Bearer '),
//       message: 'Invalid authorization header',
//     )
//     .transform((v) => v.substring(7).trim())
//     .refine(
//       (v) => v.isNotEmpty,
//       message: 'Invalid authorization header',
//     );

// todo: remove this and re-enable the above refinements once we have a proper URL validator in place (e.g. via zod_url package or custom implementation)
final _urlEndpointSchema = z.string();
final _bearerSchema = z.string();

// ─── Internal helper ─────────────────────────────────────────────────────────

T _validate<T>(
  ZemaSchema<dynamic, T> schema,
  dynamic input,
  ValidationSource source,
) {
  final result = schema.safeParse(input);

  if (result.isFailure) {
    final message = result.errors.map((e) {
      final prefix = e.path.isEmpty ? '' : '${e.pathString}: ';
      return '$prefix${e.message}';
    }).join(', ');

    _log.warning('Validation failed [${source.name}]: $message');
    throw BadRequestError(message);
  }

  return result.value;
}

// ─── Public API ──────────────────────────────────────────────────────────────

Map<String, dynamic> validateSchema<O extends Map<String, dynamic>>(
  ZemaSchema<dynamic, O> schema,
  Map<String, dynamic> input, {
  ValidationSource source = ValidationSource.body,
}) =>
    _validate(schema, input, source);

String validateUrlEndpoint(String value) =>
    _validate(_urlEndpointSchema, value, ValidationSource.param);

String validateAuthBearer(String value) =>
    _validate(_bearerSchema, value, ValidationSource.header);

Future<Map<String, dynamic>> readJsonBody(Request request) async {
  final raw = await request.readAsString();
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw const BadRequestError('Invalid request body');
  }
  return decoded;
}
