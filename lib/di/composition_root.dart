import 'dart:async';

import 'package:dart_backend_architecture/cache/cache_service.dart';
import 'package:dart_backend_architecture/cache/repository/user_cache.dart';
import 'package:dart_backend_architecture/config.dart';
import 'package:dart_backend_architecture/core/jwt/jwt_service.dart';
import 'package:dart_backend_architecture/core/logger.dart';
import 'package:dart_backend_architecture/core/middleware/rate_limit_middleware.dart'
    show RateLimitStore;
import 'package:dart_backend_architecture/database/db_pool.dart';
import 'package:dart_backend_architecture/database/repository/impl/postgres_api_key_repo.dart';
import 'package:dart_backend_architecture/database/repository/impl/postgres_blog_repo.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/api_key_repo.dart';
import 'package:dart_backend_architecture/database/repository/impl/postgres_keystore_repo.dart';
import 'package:dart_backend_architecture/database/repository/impl/postgres_role_repo.dart';
import 'package:dart_backend_architecture/database/repository/impl/postgres_user_repo.dart';
import 'package:dart_backend_architecture/routes/router.dart';
import 'package:dart_backend_architecture/services/auth_service.dart';
import 'package:dart_backend_architecture/services/token_service.dart';
import 'package:dart_backend_architecture/workers/crypto_sync.dart'
    show CryptoSync;
import 'package:shelf/shelf.dart';

final _log = AppLogger.get('CompositionRoot');

/// Central wiring point for all concrete infrastructure.
/// Keeps creation order, lifetimes and disposal in one place so the rest
/// of the code can depend purely on abstractions/interfaces.
final class CompositionRoot {
  final DatabasePool _db;
  final CacheService _cache;
  final CryptoSync _crypto;
  final JwtService _jwtService;
  final TokenService _tokenService;
  final ApiKeyRepo apiKeyRepo;
  final Timer? _keystoreGcTimer;

  CompositionRoot._({
    required DatabasePool db,
    required CacheService cache,
    required CryptoSync crypto,
    required JwtService jwtService,
    required TokenService tokenService,
    required this.apiKeyRepo,
    required Timer? keystoreGcTimer,
  })  : _db = db,
        _cache = cache,
        _crypto = crypto,
        _jwtService = jwtService,
        _tokenService = tokenService,
        _keystoreGcTimer = keystoreGcTimer;

  /// Initialize infrastructure dependencies once at process start.
  /// EventBus is always [NoOpEventBus] — replaces with a real transport
  /// when async event consumers exist.
  static Future<CompositionRoot> initialize(AppConfig config) async {
    final db = await DatabasePool.connect(
      config.databaseUrl,
      maxConnections: config.dbPoolSize,
    );
    final cache = await CacheService.connect(config.redisUrl);

    final jwtService = JwtService(
      privateKeyPath: config.jwtPrivateKeyPath,
      publicKeyPath: config.jwtPublicKeyPath,
      privateKeyPem: config.jwtPrivateKeyPem,
      publicKeyPem: config.jwtPublicKeyPem,
      accessTokenExpiry: Duration(seconds: config.jwtAccessTokenExpiry),
      refreshTokenExpiry: Duration(seconds: config.jwtRefreshTokenExpiry),
    );

    final keystoreRepo = PostgresKeystoreRepo(db);
    final keystoreGcTimer = Timer.periodic(
      const Duration(hours: 1),
      (_) => _runKeystoreGc(keystoreRepo),
    );
    final userCache = UserCache(cache);
    final tokenService = TokenService(
      keystoreRepo: keystoreRepo,
      jwt: jwtService,
      userCache: userCache,
    );
    final apiKeyRepo = PostgresApiKeyRepo(db);

    final crypto = CryptoSync();

    return CompositionRoot._(
      db: db,
      cache: cache,
      crypto: crypto,
      jwtService: jwtService,
      tokenService: tokenService,
      apiKeyRepo: apiKeyRepo,
      keystoreGcTimer: keystoreGcTimer,
    );
  }

  static void _runKeystoreGc(PostgresKeystoreRepo repo) {
    repo.deleteExpired(olderThan: const Duration(days: 90)).then((count) {
      if (count > 0) {
        _log.info('Keystore GC: deleted $count expired rows');
      }
    }).catchError((Object e) {
      _log.warning('Keystore GC failed: $e');
    });
  }

  // ── Repositories ───────────────────────────────────────────────────────────

  late final PostgresKeystoreRepo _keystoreRepo = PostgresKeystoreRepo(_db);

  late final PostgresRoleRepo _roleRepo = PostgresRoleRepo(_db);

  late final PostgresUserRepo _userRepo =
      PostgresUserRepo(_db, _keystoreRepo, _roleRepo);

  late final UserCache _userCache = UserCache(_cache);

  late final PostgresBlogRepo _blogRepo = PostgresBlogRepo(_db);

  // ── Application services ───────────────────────────────────────────────────

  late final AuthService _authService = AuthService(
    userRepo: _userRepo,
    jwt: _jwtService,
    crypto: _crypto,
    tokenService: _tokenService,
  );

  RateLimitStore get rateLimitStore => _cache;

  // ── HTTP handler ───────────────────────────────────────────────────────────

  late final Handler router = buildRouter(
    authService: _authService,
    blogRepo: _blogRepo,
    jwtService: _jwtService,
    userRepo: _userRepo,
    keystoreRepo: _keystoreRepo,
    roleRepo: _roleRepo,
    userCache: _userCache,
    dbCheck: () async {
      await _db.execute('SELECT 1');
      return true;
    },
    cacheCheck: () => _cache.ping(),
  );

  /// Release resources in reverse dependency order. Call on graceful shutdown.
  Future<void> dispose() async {
    _keystoreGcTimer?.cancel();
    await _cache.close();
    await _db.close();
  }
}
