import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/core/logger.dart';
import 'package:dart_backend_architecture/database/model/user.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/keystore_repo.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/role_repo.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/user_repo.dart';
import 'package:postgres/postgres.dart';

final class PostgresUserRepo implements UserRepo {
  final Pool<dynamic> _pool;
  final KeystoreRepo _keystoreRepo;
  final RoleRepo _roleRepo;
  final _log = AppLogger.get('PostgresUserRepo');

  PostgresUserRepo(this._pool, this._keystoreRepo, this._roleRepo);

  static const _selectFields = '''
    u.id,
    u.email,
    u.name,
    u.profile_pic_url,
    u.created_at,
    COALESCE(array_remove(array_agg(r.code), NULL), ARRAY[]::text[]) AS roles
  ''';

  @override
  Future<UserWithKeystore> create(
    User user,
    String accessTokenKey,
    String refreshTokenKey,
    String roleCode,
  ) async {
    try {
      final now = DateTime.now().toUtc();
      final role = await _roleRepo.findByCode(roleCode);
      if (role == null) {
        throw const InternalError('Role must be defined');
      }

      final result = await _pool.execute(
        Sql.named('''
          INSERT INTO users (id, email, name, password_hash, profile_pic_url, created_at, updated_at)
          VALUES (@id, @email, @name, @passwordHash, @profilePicUrl, @createdAt, @updatedAt)
          RETURNING $_selectFields
        '''),
        parameters: {
          'id': user.id,
          'email': user.email,
          'name': user.name,
          // Current domain model has no password field yet.
          'passwordHash': '',
          'profilePicUrl': user.profilePicUrl,
          'createdAt': user.createdAt,
          'updatedAt': now,
        },
      );

      final createdUser = User.fromRow(result.first);
      await _pool.execute(
        Sql.named('''
          INSERT INTO user_roles (user_id, role_id, created_at)
          VALUES (@userId, @roleId, @createdAt)
          ON CONFLICT (user_id, role_id) DO NOTHING
        '''),
        parameters: {
          'userId': createdUser.id,
          'roleId': role.id,
          'createdAt': now,
        },
      );

      final keystore = await _keystoreRepo.create(
        createdUser,
        accessTokenKey,
        refreshTokenKey,
      );

      return (user: createdUser, keystore: keystore);
    } catch (e, st) {
      _log.severe('create failed', e, st);
      throw const InternalError();
    }
  }

  @override
  Future<User?> findByEmail(String email) async {
    try {
      final result = await _pool.execute(
        Sql.named(
          '''
          SELECT $_selectFields
          FROM users u
          LEFT JOIN user_roles ur ON ur.user_id = u.id
          LEFT JOIN roles r ON r.id = ur.role_id AND r.status = TRUE
          WHERE u.email = @email AND u.deleted_at IS NULL
          GROUP BY u.id, u.email, u.name, u.profile_pic_url, u.created_at
          ''',
        ),
        parameters: {'email': email},
      );
      if (result.isEmpty) return null;
      return User.fromRow(result.first);
    } catch (e, st) {
      _log.severe('findByEmail failed', e, st);
      throw const InternalError();
    }
  }

  @override
  Future<User?> findById(String id) async {
    try {
      final result = await _pool.execute(
        Sql.named(
          '''
          SELECT $_selectFields
          FROM users u
          LEFT JOIN user_roles ur ON ur.user_id = u.id
          LEFT JOIN roles r ON r.id = ur.role_id AND r.status = TRUE
          WHERE u.id = @id AND u.deleted_at IS NULL
          GROUP BY u.id, u.email, u.name, u.profile_pic_url, u.created_at
          ''',
        ),
        parameters: {'id': id},
      );
      if (result.isEmpty) return null;
      return User.fromRow(result.first);
    } catch (e, st) {
      _log.severe('findById failed', e, st);
      throw const InternalError();
    }
  }

  @override
  Future<User?> findProfileById(String id) async {
    try {
      final result = await _pool.execute(
        Sql.named(
          '''
          SELECT $_selectFields
          FROM users u
          LEFT JOIN user_roles ur ON ur.user_id = u.id
          LEFT JOIN roles r ON r.id = ur.role_id AND r.status = TRUE
          WHERE u.id = @id AND u.deleted_at IS NULL
          GROUP BY u.id, u.email, u.name, u.profile_pic_url, u.created_at
          ''',
        ),
        parameters: {'id': id},
      );
      if (result.isEmpty) return null;
      return User.fromRow(result.first);
    } catch (e, st) {
      _log.severe('findProfileById failed', e, st);
      throw const InternalError();
    }
  }

  @override
  Future<User?> findPublicProfileById(String id) async {
    try {
      final result = await _pool.execute(
        Sql.named(
          '''
          SELECT $_selectFields
          FROM users u
          LEFT JOIN user_roles ur ON ur.user_id = u.id
          LEFT JOIN roles r ON r.id = ur.role_id AND r.status = TRUE
          WHERE u.id = @id AND u.deleted_at IS NULL
          GROUP BY u.id, u.email, u.name, u.profile_pic_url, u.created_at
          ''',
        ),
        parameters: {'id': id},
      );
      if (result.isEmpty) return null;
      return User.fromRow(result.first);
    } catch (e, st) {
      _log.severe('findPublicProfileById failed', e, st);
      throw const InternalError();
    }
  }

  @override
  Future<UserWithKeystore> update(
    User user,
    String accessTokenKey,
    String refreshTokenKey,
  ) async {
    try {
      final now = DateTime.now().toUtc();
      final result = await _pool.execute(
        Sql.named('''
          UPDATE users
          SET
            email = @email,
            name = @name,
            profile_pic_url = @profilePicUrl,
            updated_at = @updatedAt
          WHERE id = @id AND deleted_at IS NULL
          RETURNING id, email, name, profile_pic_url, created_at
        '''),
        parameters: {
          'id': user.id,
          'email': user.email,
          'name': user.name,
          'profilePicUrl': user.profilePicUrl,
          'updatedAt': now,
        },
      );

      if (result.isEmpty) {
        throw const NotFoundError('User not found');
      }

      final updatedUser = User(
        id: result.first[0] as String,
        email: result.first[1] as String,
        name: result.first[2] as String,
        profilePicUrl: result.first[3] as String?,
        createdAt: result.first[4] as DateTime,
      );
      final keystore = await _keystoreRepo.create(
        updatedUser,
        accessTokenKey,
        refreshTokenKey,
      );
      return (user: updatedUser, keystore: keystore);
    } on ApiError {
      rethrow;
    } catch (e, st) {
      _log.severe('update failed', e, st);
      throw const InternalError();
    }
  }

  @override
  Future<void> updateInfo(User user) async {
    try {
      await _pool.execute(
        Sql.named('''
          UPDATE users
          SET
            email = @email,
            name = @name,
            profile_pic_url = @profilePicUrl,
            updated_at = @updatedAt
          WHERE id = @id AND deleted_at IS NULL
        '''),
        parameters: {
          'id': user.id,
          'email': user.email,
          'name': user.name,
          'profilePicUrl': user.profilePicUrl,
          'updatedAt': DateTime.now().toUtc(),
        },
      );
    } catch (e, st) {
      _log.severe('updateInfo failed', e, st);
      throw const InternalError();
    }
  }

}
