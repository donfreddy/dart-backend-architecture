import 'package:dart_backend_architecture/cache/cache_service.dart';
import 'package:dart_backend_architecture/config.dart';
import 'package:dart_backend_architecture/core/jwt/jwt_service.dart';
import 'package:dart_backend_architecture/database/db_pool.dart';
import 'package:dart_backend_architecture/database/repository/impl/postgres_blog_repo.dart';
import 'package:dart_backend_architecture/database/repository/impl/postgres_keystore_repo.dart';
import 'package:dart_backend_architecture/database/repository/impl/postgres_role_repo.dart';
import 'package:dart_backend_architecture/database/repository/impl/postgres_user_repo.dart';
import 'package:dart_backend_architecture/messaging/nats_service.dart';
import 'package:dart_backend_architecture/routes/router.dart';
import 'package:dart_backend_architecture/services/auth_service.dart';
import 'package:dart_backend_architecture/services/blog_service.dart';
import 'package:dart_backend_architecture/workers/crypto_worker.dart';
import 'package:shelf/shelf.dart';

// The only module that wires concrete implementations.
// The rest of the codebase depends on abstractions/interfaces.
final class CompositionRoot {
  final AppConfig _config;
  final DatabasePool _db;
  final CacheService _cache;
  final NatsService _nats;
  final CryptoWorker _crypto;

  CompositionRoot._({
    required AppConfig config,
    required DatabasePool db,
    required CacheService cache,
    required NatsService nats,
    required CryptoWorker crypto,
  })  : _config = config,
        _db = db,
        _cache = cache,
        _nats = nats,
        _crypto = crypto;

  // Initialize all infrastructure dependencies once at startup.
  static Future<CompositionRoot> initialize(AppConfig config) async {
    final db = await DatabasePool.connect(config.databaseUrl);
    final cache = await CacheService.connect(config.redisUrl);
    final nats = await NatsService.connect(config.natsUrl);
    final crypto = await CryptoWorker.spawn();

    return CompositionRoot._(
      config: config,
      db: db,
      cache: cache,
      nats: nats,
      crypto: crypto,
    );
  }

  // Repositories
  PostgresUserRepo get _userRepo => PostgresUserRepo(_db.pool, _keystoreRepo, _roleRepo);
  PostgresBlogRepo get _blogRepo => PostgresBlogRepo(_db.pool);
  PostgresKeystoreRepo get _keystoreRepo => PostgresKeystoreRepo(_db.pool);
  PostgresRoleRepo get _roleRepo => PostgresRoleRepo(_db.pool);

  // Core services
  JwtService get _jwtService => JwtService(
        privateKeyPath: _config.jwtPrivateKeyPath,
        publicKeyPath: _config.jwtPublicKeyPath,
        accessTokenExpiry: Duration(seconds: _config.jwtAccessTokenExpiry),
        refreshTokenExpiry: Duration(seconds: _config.jwtRefreshTokenExpiry),
      );

  // Application services
  AuthService get _authService => AuthService(
        userRepo: _userRepo,
        keystoreRepo: _keystoreRepo,
        jwt: _jwtService,
        crypto: _crypto,
      );

  BlogService get _blogService => BlogService(
        blogRepo: _blogRepo,
        // cache: _cache,
        // nats: _nats,
      );

  // HTTP entrypoint
  Handler get router => buildRouter(
        authService: _authService,
        blogService: _blogService,
        jwtService: _jwtService,
        userRepo: _userRepo,
        keystoreRepo: _keystoreRepo,
      );

  // Release resources in reverse dependency order.
  Future<void> dispose() async {
    await _nats.close();
    await _cache.close();
    await _db.close();
    await _crypto.dispose();
  }
}
