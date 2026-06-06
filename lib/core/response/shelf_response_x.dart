import 'dart:convert';

import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:shelf/shelf.dart';

Response ok({String message = 'ok', Object? data, int status = 200}) {
  return Response(
    status,
    body: jsonEncode({
      'message': message,
      if (data != null) 'data': data,
    }),
    headers: {'content-type': 'application/json'},
  );
}

Response okPaginated({
  required List<Object?> items,
  required int page,
  required int limit,
  required int total,
}) {
  return Response(
    200,
    body: jsonEncode({
      'message': 'ok',
      'data': {
        'items': items,
        'meta': {
          'total_items': total,
          'current_page': page,
          'items_per_page': limit,
        },
      },
    }),
    headers: {'content-type': 'application/json'},
  );
}

Response fail({required ApiError error, Object? data}) {
  final body = <String, Object?>{
    'message': error.message,
  };
  if (data != null) body['data'] = data;

  final headers = <String, String>{
    'content-type': 'application/json',
  };
  if (error.type == ErrorType.accessToken) {
    headers['instruction'] = 'refresh_token';
  }

  return Response(
    error.type.httpStatus,
    body: jsonEncode(body),
    headers: headers,
  );
}
