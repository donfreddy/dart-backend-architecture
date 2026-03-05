import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/core/middleware/auth_middleware.dart';
import 'package:dart_backend_architecture/database/model/user.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/role_repo.dart';
import 'package:shelf/shelf.dart';

const currentRoleCodeKey = 'current_role_code';

Middleware authorizationMiddleware({
  required RoleRepo roleRepo,
  required String roleCode,
}) {
  return (Handler inner) {
    return (Request request) async {
      if (roleCode.isEmpty) {
        throw const AuthFailureError('Permission denied');
      }

      final user = _requireAuthenticatedUser(request);
      if (user.roles.isEmpty) {
        throw const AuthFailureError('Permission denied');
      }

      final role = await roleRepo.findByCode(roleCode);
      if (role == null) {
        throw const AuthFailureError('Permission denied');
      }

      final hasRole = user.roles.any((userRoleCode) => userRoleCode == role.code);
      if (!hasRole) {
        throw const AuthFailureError('Permission denied');
      }

      return inner(
        request.change(
          context: {
            ...request.context,
            currentRoleCodeKey: roleCode,
          },
        ),
      );
    };
  };
}

extension AuthorizedRequest on Request {
  String get currentRoleCode {
    final roleCode = context[currentRoleCodeKey];
    if (roleCode is String && roleCode.isNotEmpty) return roleCode;
    throw StateError('current_role_code not found in request context');
  }
}

User _requireAuthenticatedUser(Request request) {
  try {
    return request.authUser;
  } on StateError {
    throw const AuthFailureError('Permission denied');
  }
}
