import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/core/response/api_response.dart';
import 'package:dart_backend_architecture/core/response/shelf_response_x.dart';
import 'package:shelf/shelf.dart';

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
