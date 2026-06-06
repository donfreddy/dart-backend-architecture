import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/core/logger.dart';
import 'package:dart_backend_architecture/database/model/api_key.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/api_key_repo.dart';
import 'package:dart_backend_architecture/database/db_pool.dart';
import 'package:postgres/postgres.dart';

final class PostgresApiKeyRepo implements ApiKeyRepo {
  final DatabasePool _pool;
  final _log = AppLogger.get('PostgresApiKeyRepo');

  PostgresApiKeyRepo(this._pool);

  @override
  Future<ApiKey?> findByKey(String key) async {
    try {
      final result = await _pool.execute(
        Sql.named('''
          SELECT key, version, metadata, status, created_at, updated_at
          FROM api_keys
          WHERE key = @key AND status = TRUE
          LIMIT 1
        '''),
        parameters: {'key': key},
      );

      if (result.isEmpty) return null;
      final row = result.first.toColumnMap();

      return ApiKey(
        key: row['key'] as String,
        version: row['version'] as int,
        metadata: row['metadata'] as String,
        status: row['status'] as bool?,
        createdAt: row['created_at'] as DateTime?,
        updatedAt: row['updated_at'] as DateTime?,
      );
    } catch (e, st) {
      _log.severe('findByKey failed', e, st);
      throw const InternalError();
    }
  }
}
