import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/core/logger.dart';
import 'package:dart_backend_architecture/database/model/role.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/role_repo.dart';
import 'package:dart_backend_architecture/database/db_pool.dart';
import 'package:postgres/postgres.dart';

final class PostgresRoleRepo implements RoleRepo {
  final DatabasePool _pool;
  final _log = AppLogger.get('PostgresRoleRepo');

  PostgresRoleRepo(this._pool);

  @override
  Future<Role?> findByCode(String code) async {
    try {
      final result = await _pool.execute(
        Sql.named('''
          SELECT id, code, status, created_at, updated_at
          FROM roles
          WHERE code = @code AND status = TRUE
          LIMIT 1
        '''),
        parameters: {'code': code},
      );

      if (result.isEmpty) return null;
      final row = result.first.toColumnMap();

      return Role(
        id: row['id'] as String,
        code: row['code'] as String,
        status: row['status'] as bool?,
        createdAt: row['created_at'] as DateTime?,
        updatedAt: row['updated_at'] as DateTime?,
      );
    } catch (e, st) {
      _log.severe('findByCode failed', e, st);
      throw const InternalError();
    }
  }
}
