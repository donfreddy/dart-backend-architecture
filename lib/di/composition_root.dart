import 'package:dart_backend_architecture/cache/cache_service.dart';
import 'package:dart_backend_architecture/cache/repository/blog_cache.dart';
import 'package:dart_backend_architecture/cache/repository/user_cache.dart';
import 'package:dart_backend_architecture/config.dart';
import 'package:dart_backend_architecture/core/jwt/jwt_service.dart';
import 'package:dart_backend_architecture/core/logger.dart';
import 'package:dart_backend_architecture/database/db_pool.dart';
import 'package:dart_backend_architecture/database/repository/caching_blog_repo.dart';
import 'package:dart_backend_architecture/database/repository/impl/postgres_blog_repo.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/blog_repo.dart';
import 'package:dart_backend_architecture/database/repository/impl/postgres_keystore_repo.dart';
import 'package:dart_backend_architecture/database/repository/impl/postgres_role_repo.dart';
import 'package:dart_backend_architecture/database/repository/impl/postgres_user_repo.dart';
import 'package:dart_backend_architecture/messaging/event_bus.dart';
import 'package:dart_backend_architecture/messaging/nats_event_bus.dart';
import 'package:dart_backend_architecture/messaging/nats_service.dart';
import 'package:dart_backend_architecture/messaging/no_op_event_bus.dart';
import 'package:dart_backend_architecture/routes/router.dart';
import 'package:dart_backend_architecture/services/auth_service.dart';
import 'package:dart_backend_architecture/services/blog_service.dart';
import 'package:dart_backend_architecture/services/token_service.dart';
import 'package:dart_backend_architecture/workers/crypto_worker.dart';
import 'package:shelf/shelf.dart';

final _log = AppLogger.get('CompositionRoot');

/// Central wiring point for all concrete infrastructure.
/// Keeps creation order, lifetimes and disposal in one place so the rest
/// of the code can depend purely on abstractions/interfaces.
final class CompositionRoot {
  final DatabasePool _db;
  final CacheService _cache;
  final EventBus _eventBus;
  final CryptoWorker _crypto;
  final JwtService _jwtService;
  final TokenService _tokenService;

  CompositionRoot._({
    required DatabasePool db,
    required CacheService cache,
    required EventBus eventBus,
    required CryptoWorker crypto,
    required JwtService jwtService,
    required TokenService tokenService,
  })  : _db = db,
        _cache = cache,
        _eventBus = eventBus,
        _crypto = crypto,
        _jwtService = jwtService,
        _tokenService = tokenService;

  /// Initialize infrastructure dependencies once at process start.
  /// NATS connection is optional: if [NATS_URL] is empty a [NoOpEventBus]
  /// is used so the application starts without a NATS broker.
  static Future<CompositionRoot> initialize(AppConfig config) async {
    final db = await DatabasePool.connect(
      config.databaseUrl,
      maxConnections: config.dbPoolSize,
    );
    final cache = await CacheService.connect(config.redisUrl);
    final eventBus = await _initEventBus(config.natsUrl);
    final crypto = await CryptoWorker.spawn();

    final jwtService = JwtService(
      privateKeyPath: config.jwtPrivateKeyPath,
      publicKeyPath: config.jwtPublicKeyPath,
      privateKeyPem: config.jwtPrivateKeyPem,
      publicKeyPem: config.jwtPublicKeyPem,
      accessTokenExpiry: Duration(seconds: config.jwtAccessTokenExpiry),
      refreshTokenExpiry: Duration(seconds: config.jwtRefreshTokenExpiry),
    );
    await jwtService.initWorker();

    final keystoreRepo = PostgresKeystoreRepo(db.pool);
    final userCache = UserCache(cache);
    final tokenService = TokenService(
      keystoreRepo: keystoreRepo,
      jwt: jwtService,
      userCache: userCache,
    );

    return CompositionRoot._(
      db: db,
      cache: cache,
      eventBus: eventBus,
      crypto: crypto,
      jwtService: jwtService,
      tokenService: tokenService,
    );
  }

  static Future<EventBus> _initEventBus(String natsUrl) async {
    if (natsUrl.isEmpty) {
      _log.info('NATS_URL not set — using NoOpEventBus (events disabled)');
      return const NoOpEventBus();
    }
    final nats = await NatsService.connect(natsUrl);
    return NatsEventBus(nats);
  }

  // ── Repositories ───────────────────────────────────────────────────────────

  PostgresUserRepo get _userRepo =>
      PostgresUserRepo(_db.pool, _keystoreRepo, _roleRepo);
  PostgresKeystoreRepo get _keystoreRepo => PostgresKeystoreRepo(_db.pool);
  PostgresRoleRepo get _roleRepo => PostgresRoleRepo(_db.pool);
  UserCache get _userCache => UserCache(_cache);

  // CachingBlogRepo wraps the Postgres implementation with read-through caching
  // and write invalidation, keeping BlogService free of cache concerns.
  BlogRepo get _cachingBlogRepo => CachingBlogRepo(
        inner: PostgresBlogRepo(_db.pool),
        cache: BlogCache(_cache),
      );

  // ── Application services ───────────────────────────────────────────────────

  AuthService get _authService => AuthService(
        userRepo: _userRepo,
        jwt: _jwtService,
        crypto: _crypto,
        tokenService: _tokenService,
      );

  BlogService get _blogService => BlogService(
        blogRepo: _cachingBlogRepo,
        eventBus: _eventBus,
      );

  // ── HTTP handler ───────────────────────────────────────────────────────────

  /// Fully-wired HTTP handler including health/readiness endpoints.
  Handler get router => buildRouter(
        authService: _authService,
        blogService: _blogService,
        jwtService: _jwtService,
        userRepo: _userRepo,
        keystoreRepo: _keystoreRepo,
        roleRepo: _roleRepo,
        userCache: _userCache,
        dbCheck: () async {
          await _db.pool.execute('SELECT 1');
          return true;
        },
        cacheCheck: () => _cache.ping(),
        natsCheck: () => _eventBus.ping(),
      );

  /// Release resources in reverse dependency order. Call on graceful shutdown.
  Future<void> dispose() async {
    await _jwtService.dispose();
    await _eventBus.close();
    await _cache.close();
    await _db.close();
    await _crypto.dispose();
  }
}
