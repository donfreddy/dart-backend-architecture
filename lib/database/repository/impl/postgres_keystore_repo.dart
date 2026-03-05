import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/core/logger.dart';
import 'package:dart_backend_architecture/database/model/keystore.dart';
import 'package:dart_backend_architecture/database/model/user.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/keystore_repo.dart';
import 'package:postgres/postgres.dart';

final class PostgresKeystoreRepo implements KeystoreRepo {
  final Pool<dynamic> _pool;
  final _log = AppLogger.get('PostgresKeystoreRepo');

  PostgresKeystoreRepo(this._pool);

  static const _selectFields = '''
    k.id,
    k.client_id,
    k.primary_key,
    k.secondary_key,
    k.status,
    k.created_at,
    k.updated_at,
    u.id,
    u.email,
    u.name,
    u.profile_pic_url,
    u.created_at
  ''';

  @override
  Future<Keystore> create(User client, String primaryKey, String secondaryKey) async {
    try {
      final now = DateTime.now().toUtc();
      final result = await _pool.execute(
        Sql.named('''
          INSERT INTO keystores (client_id, primary_key, secondary_key, status, created_at, updated_at)
          VALUES (@clientId, @primaryKey, @secondaryKey, @status, @createdAt, @updatedAt)
          RETURNING id, client_id, primary_key, secondary_key, status, created_at, updated_at
        '''),
        parameters: {
          'clientId': client.id,
          'primaryKey': primaryKey,
          'secondaryKey': secondaryKey,
          'status': true,
          'createdAt': now,
          'updatedAt': now,
        },
      );

      final row = result.first;
      return Keystore(
        client: client,
        primaryKey: row[2] as String,
        secondaryKey: row[3] as String,
        status: row[4] as bool?,
        createdAt: row[5] as DateTime?,
        updatedAt: row[6] as DateTime?,
      );
    } catch (e, st) {
      _log.severe('create failed', e, st);
      throw const InternalError();
    }
  }

  @override
  Future<Keystore?> find(User client, String primaryKey, String secondaryKey) async {
    try {
      final result = await _pool.execute(
        Sql.named('''
          SELECT $_selectFields
          FROM keystores k
          INNER JOIN users u ON u.id = k.client_id
          WHERE k.client_id = @clientId
            AND k.primary_key = @primaryKey
            AND k.secondary_key = @secondaryKey
            AND k.status = TRUE
            AND k.deleted_at IS NULL
            AND u.deleted_at IS NULL
          ORDER BY k.created_at DESC
          LIMIT 1
        '''),
        parameters: {
          'clientId': client.id,
          'primaryKey': primaryKey,
          'secondaryKey': secondaryKey,
        },
      );

      if (result.isEmpty) return null;
      return _mapKeystore(result.first);
    } catch (e, st) {
      _log.severe('find failed', e, st);
      throw const InternalError();
    }
  }

  @override
  Future<Keystore?> findForKey(User client, String key) async {
    try {
      final result = await _pool.execute(
        Sql.named('''
          SELECT $_selectFields
          FROM keystores k
          INNER JOIN users u ON u.id = k.client_id
          WHERE k.client_id = @clientId
            AND k.primary_key = @key
            AND k.status = TRUE
            AND k.deleted_at IS NULL
            AND u.deleted_at IS NULL
          ORDER BY k.created_at DESC
          LIMIT 1
        '''),
        parameters: {
          'clientId': client.id,
          'key': key,
        },
      );

      if (result.isEmpty) return null;
      return _mapKeystore(result.first);
    } catch (e, st) {
      _log.severe('findForKey failed', e, st);
      throw const InternalError();
    }
  }

  @override
  Future<Keystore?> remove(String id) async {
    try {
      final existing = await _pool.execute(
        Sql.named('''
          SELECT $_selectFields
          FROM keystores k
          INNER JOIN users u ON u.id = k.client_id
          WHERE k.id = @id AND u.deleted_at IS NULL
          LIMIT 1
        '''),
        parameters: {'id': id},
      );

      if (existing.isEmpty) return null;

      await _pool.execute(
        Sql.named('DELETE FROM keystores WHERE id = @id'),
        parameters: {'id': id},
      );

      return _mapKeystore(existing.first);
    } catch (e, st) {
      _log.severe('remove failed', e, st);
      throw const InternalError();
    }
  }

  Keystore _mapKeystore(ResultRow row) {
    final client = User(
      id: row[7] as String,
      email: row[8] as String,
      name: row[9] as String,
      profilePicUrl: row[10] as String?,
      createdAt: row[11] as DateTime,
    );

    return Keystore(
      client: client,
      primaryKey: row[2] as String,
      secondaryKey: row[3] as String,
      status: row[4] as bool?,
      createdAt: row[5] as DateTime?,
      updatedAt: row[6] as DateTime?,
    );
  }
}
