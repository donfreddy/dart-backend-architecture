import 'dart:convert';

import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/core/response/api_response.dart';
import 'package:shelf/shelf.dart';

extension ShelfResponseX on ApiResponse<dynamic> {
  Response toShelfResponse({
    int? status,
    Map<String, String>? headers,
  }) {
    final resolvedStatus = status ?? _defaultHttpStatus(this);

    return Response(
      resolvedStatus,
      body: jsonEncode(toMap()),
      headers: {
        'content-type': 'application/json',
        ...?headers,
        if (this case Failure(error: final error) when error.type == ErrorType.accessToken)
          'instruction': 'refresh_token',
      },
    );
  }
}

int _defaultHttpStatus(ApiResponse<dynamic> result) {
  return switch (result) {
    Success<dynamic>() => 200,
    Failure(error: final error) => error.type.httpStatus,
  };
}
