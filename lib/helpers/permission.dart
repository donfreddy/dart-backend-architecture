import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/database/model/role.dart';
import 'package:dart_backend_architecture/database/model/user.dart';

typedef RoleList = Iterable<String>;

abstract final class Permission {
  Permission._();

  static final List<String> allRoles = <String>[
    RoleCode.learner.value,
    RoleCode.writer.value,
    RoleCode.editor.value,
    RoleCode.admin.value,
  ];

  static void require({
    required RoleList userRoles,
    required String role,
  }) {
    if (!userRoles.contains(role)) {
      throw ForbiddenError('Role $role required');
    }
  }

  static void requireAny({
    required RoleList userRoles,
    required Iterable<String> roles,
  }) {
    final hasAny = roles.any(userRoles.contains);
    if (!hasAny) {
      throw ForbiddenError('One of ${roles.join(', ')} required');
    }
  }

  static void requireAll({
    required RoleList userRoles,
    required Iterable<String> roles,
  }) {
    final hasAll = roles.every(userRoles.contains);
    if (!hasAll) {
      throw ForbiddenError('All of ${roles.join(', ')} required');
    }
  }

  static bool has({
    required RoleList userRoles,
    required String role,
  }) {
    return userRoles.contains(role);
  }

  static bool hasAny({
    required RoleList userRoles,
    required Iterable<String> roles,
  }) {
    return roles.any(userRoles.contains);
  }

  static void requireOwnership({
    required String resourceOwnerId,
    required String requesterId,
    String resource = 'resource',
  }) {
    if (resourceOwnerId != requesterId) {
      throw ForbiddenError('You do not own this $resource');
    }
  }

  static void requireOwnershipOrRole({
    required String resourceOwnerId,
    required String requesterId,
    required RoleList userRoles,
    required Iterable<String> roles,
    String resource = 'resource',
  }) {
    final isOwner = resourceOwnerId == requesterId;
    final hasRole = roles.any(userRoles.contains);
    if (!isOwner && !hasRole) {
      throw ForbiddenError(
        'You must own this $resource or have one of: ${roles.join(', ')}',
      );
    }
  }
}

extension UserPermissionX on User {
  void requireRole(String role) {
    Permission.require(userRoles: roles, role: role);
  }

  bool hasRole(String role) {
    return Permission.has(userRoles: roles, role: role);
  }
}
