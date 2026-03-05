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
    Success<dynamic>() || PaginatedResponse<dynamic>() => 200,
    Failure(error: final error) => error.type.httpStatus,
  };
}

Response ok<T>({
  required String message,
  T? data,
  int? status,
  Map<String, String>? headers,
  StatusCode statusCode = StatusCode.success,
}) {
  return Success<T>(
    message: message,
    data: data,
    statusCode: statusCode,
  ).toShelfResponse(
    status: status,
    headers: headers,
  );
}

Response okPaginated<T>({
  required String message,
  required List<T> items,
  required int page,
  required int limit,
  required int total,
  int? status,
  Map<String, String>? headers,
  StatusCode statusCode = StatusCode.success,
}) {
  return PaginatedResponse<T>(
    message: message,
    items: items,
    pagination: PaginationMeta(
      page: page,
      limit: limit,
      total: total,
    ),
    statusCode: statusCode,
  ).toShelfResponse(
    status: status,
    headers: headers,
  );
}

Response fail({
  required ApiError error,
  Object? data,
  int? status,
  Map<String, String>? headers,
}) {
  return Failure(
    error: error,
    data: data,
  ).toShelfResponse(
    status: status,
    headers: headers,
  );
}
