import 'package:dart_backend_architecture/database/model/role.dart';

abstract interface class RoleRepo {
  Future<Role?> findByCode(String code);
}
