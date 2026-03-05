enum ErrorType {
  badToken,
  tokenExpired,
  unauthorized,
  accessToken,
  internal,
  notFound,
  noEntry,
  noData,
  badRequest,
  forbidden,
  validation,
  conflict,
}

extension ErrorTypeCodeX on ErrorType {
  String get code => switch (this) {
        ErrorType.badToken => 'BadTokenError',
        ErrorType.tokenExpired => 'TokenExpiredError',
        ErrorType.unauthorized => 'AuthFailureError',
        ErrorType.accessToken => 'AccessTokenError',
        ErrorType.internal => 'InternalError',
        ErrorType.notFound => 'NotFoundError',
        ErrorType.noEntry => 'NoEntryError',
        ErrorType.noData => 'NoDataError',
        ErrorType.badRequest => 'BadRequestError',
        ErrorType.forbidden => 'ForbiddenError',
        ErrorType.validation => 'ValidationError',
        ErrorType.conflict => 'ConflictError',
      };
}

extension ErrorTypeHttpX on ErrorType {
  int get httpStatus => switch (this) {
        ErrorType.badToken || ErrorType.tokenExpired || ErrorType.unauthorized || ErrorType.accessToken => 401,
        ErrorType.internal => 500,
        ErrorType.notFound || ErrorType.noEntry || ErrorType.noData => 404,
        ErrorType.badRequest || ErrorType.validation => 400,
        ErrorType.forbidden => 403,
        ErrorType.conflict => 409,
      };
}

sealed class ApiError implements Exception {
  final ErrorType type;
  final String message;

  const ApiError(this.type, [this.message = 'error']);

  String get code => type.code;

  Object? get data => null;

  Map<String, Object?> toMap() {
    final envelope = (code: code, message: message, data: data);
    return {
      'code': envelope.code,
      'message': envelope.message,
      if (envelope.data case final payload?) 'data': payload,
    };
  }

  @override
  String toString() => '$code: $message';
}

final class AuthFailureError extends ApiError {
  const AuthFailureError([String message = 'Invalid credentials']) : super(ErrorType.unauthorized, message);
}

final class InternalError extends ApiError {
  const InternalError([String message = 'Internal error']) : super(ErrorType.internal, message);
}

final class BadRequestError extends ApiError {
  const BadRequestError([String message = 'Bad request']) : super(ErrorType.badRequest, message);
}

final class NotFoundError extends ApiError {
  const NotFoundError([String message = 'Not found']) : super(ErrorType.notFound, message);
}

final class ForbiddenError extends ApiError {
  const ForbiddenError([String message = 'Permission denied']) : super(ErrorType.forbidden, message);
}

final class NoEntryError extends ApiError {
  const NoEntryError([String message = "Entry doesn't exist"]) : super(ErrorType.noEntry, message);
}

final class BadTokenError extends ApiError {
  const BadTokenError([String message = 'Token is not valid']) : super(ErrorType.badToken, message);
}

final class TokenExpiredError extends ApiError {
  const TokenExpiredError([String message = 'Token is expired']) : super(ErrorType.tokenExpired, message);
}

final class NoDataError extends ApiError {
  const NoDataError([String message = 'No data available']) : super(ErrorType.noData, message);
}

final class AccessTokenError extends ApiError {
  const AccessTokenError([String message = 'Invalid access token']) : super(ErrorType.accessToken, message);
}

final class ValidationError extends ApiError {
  final Map<String, List<String>> fieldErrors;

  const ValidationError(this.fieldErrors) : super(ErrorType.validation, 'Validation failed');

  @override
  Object? get data => {'errors': fieldErrors};
}

final class ConflictError extends ApiError {
  const ConflictError([String message = 'Already exists']) : super(ErrorType.conflict, message);
}
