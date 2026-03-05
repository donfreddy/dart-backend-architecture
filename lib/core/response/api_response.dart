import 'package:dart_backend_architecture/core/errors/api_error.dart';

enum StatusCode {
  success('10000'),
  failure('10001'),
  retry('10002'),
  invalidAccessToken('10003');

  final String value;
  const StatusCode(this.value);
}

sealed class ApiResponse<T> {
  final StatusCode statusCode;
  final String message;
  final T? data;

  const ApiResponse({
    required this.statusCode,
    required this.message,
    this.data,
  });

  String get status => statusCode.value;

  ({String status, String message, Object? data}) envelopeRecord() {
    return (
      status: status,
      message: message,
      data: data,
    );
  }

  Map<String, Object?> toMap() {
    final e = envelopeRecord();
    return {
      'status': e.status,
      'message': e.message,
      if (e.data case final payload?) 'data': payload,
    };
  }
}

final class Success<T> extends ApiResponse<T> {
  const Success({
    required super.message,
    super.data,
    super.statusCode = StatusCode.success,
  });

  /// Convenience constructor when only a message is needed.
  const Success.message(String message) : this(message: message);
}

final class PaginationMeta {
  final int page;
  final int limit;
  final int total;

  const PaginationMeta({
    required this.page,
    required this.limit,
    required this.total,
  });

  int get totalPages => limit <= 0 ? 0 : ((total + limit - 1) ~/ limit);
  bool get hasNext => page < totalPages;
  bool get hasPrevious => page > 1;

  Map<String, Object?> toMap() {
    return {
      'total_items': total,
      'current_page': page,
      'total_pages': totalPages,
      'items_per_page': limit,
      'has_next': hasNext,
      'has_previous': hasPrevious,
    };
  }
}

final class PaginatedResponse<T> extends ApiResponse<List<T>> {
  final PaginationMeta pagination;

  const PaginatedResponse({
    required super.message,
    required List<T> items,
    required this.pagination,
    super.statusCode = StatusCode.success,
  }) : super(data: items);

  @override
  Map<String, Object?> toMap() {
    return {
      'status': status,
      'message': message,
      'data': {
        'items': data ?? const [],
        'meta': pagination.toMap(),
      },
    };
  }
}

final class Failure extends ApiResponse<Object?> {
  final ApiError error;

  Failure({
    required this.error,
    super.data,
    StatusCode? statusCode,
  }) : super(
          statusCode:
              statusCode ?? (error.type == ErrorType.accessToken ? StatusCode.invalidAccessToken : StatusCode.failure),
          message: error.message,
        );

  @override
  ({String status, String message, Object? data}) envelopeRecord() {
    final base = super.envelopeRecord();
    return (
      status: base.status,
      message: base.message,
      data: base.data,
    );
  }
}
