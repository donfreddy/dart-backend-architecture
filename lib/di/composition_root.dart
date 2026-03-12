import 'package:dart_backend_architecture/cache/cache_service.dart';
import 'package:dart_backend_architecture/cache/repository/blog_cache.dart';
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

/// Central wiring point for all concrete infrastructure.
/// Keeps creation order, lifetimes and disposal in one place so the rest
/// of the code can depend purely on abstractions/interfaces.
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

  /// Initialize infrastructure dependencies once at process start.
  /// Connects DB, Redis, NATS and spawns the crypto worker.
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
  BlogCache get _blogCache => BlogCache(_cache);

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
        blogCache: _blogCache,
        nats: _nats,
      );

  /// Fully-wired HTTP handler including health/readiness endpoints.
  Handler get router => buildRouter(
        authService: _authService,
        blogService: _blogService,
        jwtService: _jwtService,
        userRepo: _userRepo,
        keystoreRepo: _keystoreRepo,
        roleRepo: _roleRepo,
        dbCheck: () async {
          await _db.pool.execute('SELECT 1');
          return true;
        },
        cacheCheck: () => _cache.ping(),
        natsCheck: () => _nats.ping(),
      );

  /// Release resources in reverse dependency order. Call on graceful shutdown.
  Future<void> dispose() async {
    await _nats.close();
    await _cache.close();
    await _db.close();
    await _crypto.dispose();
  }
}
