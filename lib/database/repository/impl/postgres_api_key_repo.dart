import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/core/logger.dart';
import 'package:dart_backend_architecture/database/model/api_key.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/api_key_repo.dart';
import 'package:postgres/postgres.dart';

final class PostgresApiKeyRepo implements ApiKeyRepo {
  final Pool<dynamic> _pool;
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
      final row = result.first;

      return ApiKey(
        key: row[0] as String,
        version: row[1] as int,
        metadata: row[2] as String,
        status: row[3] as bool?,
        createdAt: row[4] as DateTime?,
        updatedAt: row[5] as DateTime?,
      );
    } catch (e, st) {
      _log.severe('findByKey failed', e, st);
      throw const InternalError();
    }
  }
}
