import 'package:dart_backend_architecture/core/logger.dart';
import 'package:dart_backend_architecture/database/model/keystore.dart';
import 'package:dart_backend_architecture/database/model/user.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/keystore_repo.dart';
import 'package:dart_backend_architecture/database/db_pool.dart';
import 'package:postgres/postgres.dart';

final class PostgresKeystoreRepo implements KeystoreRepo {
  final DatabasePool _pool;
  final _log = AppLogger.get('PostgresKeystoreRepo');

  PostgresKeystoreRepo(this._pool);

  static const _selectFields = '''
    k.id          AS keystore_id,
    k.client_id,
    k.primary_key,
    k.secondary_key,
    k.status,
    k.created_at  AS keystore_created_at,
    k.updated_at,
    u.id          AS user_id,
    u.email,
    u.name,
    u.profile_pic_url,
    u.created_at  AS user_created_at
  ''';

  @override
  Future<Keystore> create(
    User client,
    String primaryKey,
    String secondaryKey,
  ) async {
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

    final row = result.first.toColumnMap();
    return Keystore(
      id: row['id'] as String,
      client: client,
      primaryKey: row['primary_key'] as String,
      secondaryKey: row['secondary_key'] as String,
      status: row['status'] as bool?,
      createdAt: row['created_at'] as DateTime?,
      updatedAt: row['updated_at'] as DateTime?,
    );
  }

  @override
  Future<Keystore?> find(
    User client,
    String primaryKey,
    String secondaryKey,
  ) async {
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
  }

  @override
  Future<Keystore?> findForKey(User client, String key) async {
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
  }

  @override
  Future<int> deleteExpired({required Duration olderThan}) async {
    final cutoff = DateTime.now().toUtc().subtract(olderThan);
    final result = await _pool.execute(
      Sql.named('''
        DELETE FROM keystores
        WHERE created_at < @cutoff
      '''),
      parameters: {'cutoff': cutoff},
    );
    final count = result.affectedRows;
    if (count > 0) {
      _log.info('GC: deleted $count expired keystore(s) older than ${olderThan.inDays} days');
    }
    return count;
  }

  @override
  Future<Keystore?> remove(String id) async {
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
  }

  Keystore _mapKeystore(ResultRow row) {
    final map = row.toColumnMap();
    final client = User(
      id: map['user_id'] as String,
      email: map['email'] as String,
      name: map['name'] as String,
      profilePicUrl: map['profile_pic_url'] as String?,
      createdAt: map['user_created_at'] as DateTime,
    );

    return Keystore(
      id: map['keystore_id'] as String,
      client: client,
      primaryKey: map['primary_key'] as String,
      secondaryKey: map['secondary_key'] as String,
      status: map['status'] as bool?,
      createdAt: map['keystore_created_at'] as DateTime?,
      updatedAt: map['updated_at'] as DateTime?,
    );
  }
}
