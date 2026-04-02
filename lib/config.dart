import 'dart:io';

import 'package:zema/zema.dart';

/// Strongly typed configuration loaded from `.env` + process env.
/// Provides defaults for local dev and throws on invalid/missing required vars.
final class AppConfig {
  final int port;
  final String databaseUrl;
  final String redisUrl;
  final String natsUrl;
  final String jwtPrivateKeyPath;
  final String jwtPublicKeyPath;
  final String jwtPrivateKeyPem;
  final String jwtPublicKeyPem;
  final int jwtAccessTokenExpiry;
  final int jwtRefreshTokenExpiry;
  final String otelEndpoint;
  final String environment;
  final int maxRequestBodyBytes;
  final int dbPoolSize;
  final int workerCount;
  final int initConcurrency;

  const AppConfig._({
    required this.port,
    required this.databaseUrl,
    required this.redisUrl,
    required this.natsUrl,
    required this.jwtPrivateKeyPath,
    required this.jwtPublicKeyPath,
    required this.jwtPrivateKeyPem,
    required this.jwtPublicKeyPem,
    required this.jwtAccessTokenExpiry,
    required this.jwtRefreshTokenExpiry,
    required this.otelEndpoint,
    required this.environment,
    required this.maxRequestBodyBytes,
    required this.dbPoolSize,
    required this.workerCount,
    required this.initConcurrency,
  });

  static final _schema = z.object({
    'PORT': z.coerce().integer(min: 1, max: 65535).withDefault(8080),
    'DATABASE_URL': z.string().min(1),
    'REDIS_URL': z.string().min(1),
    'NATS_URL':
        z.string().withDefault(''), // empty = NATS disabled (NoOpEventBus)
    // Keys can be supplied as file paths OR as raw PEM content via env vars.
    // At least one form must be non-empty for each key (validated in JwtService).
    'JWT_PRIVATE_KEY_PATH': z.string().withDefault(''),
    'JWT_PUBLIC_KEY_PATH': z.string().withDefault(''),
    'JWT_PRIVATE_KEY_PEM': z.string().withDefault(''),
    'JWT_PUBLIC_KEY_PEM': z.string().withDefault(''),
    'JWT_ACCESS_TOKEN_EXPIRY': z.coerce().integer(min: 1).withDefault(3600),
    'JWT_REFRESH_TOKEN_EXPIRY': z.coerce().integer(min: 1).withDefault(2592000),
    'OTEL_ENDPOINT': z.string().withDefault(''),
    'ENVIRONMENT': z.string().oneOf(
      ['development', 'test', 'production'],
    ).withDefault('development'),
    'MAX_REQUEST_BODY_BYTES':
        z.coerce().integer(min: 1024).withDefault(1024 * 1024),
    'DB_POOL_SIZE': z.coerce().integer(min: 1).withDefault(20),
    'WORKER_COUNT': z.coerce().integer(min: 0).withDefault(0),
    'INIT_CONCURRENCY': z.coerce().integer(min: 1).withDefault(2),
  });

  /// Load configuration from `.env` (if present) and environment variables.
  factory AppConfig.fromEnv() {
    final envSource = <String, String>{
      ..._loadDotEnv('.env'),
      ..._loadDotEnv(
        '.env.test',
      ), // overrides .env when present (local test runs)
      ...Platform.environment, // process env always wins (Docker, CI)
    };

    final result = _schema.safeParse(envSource);
    if (result.isFailure) {
      throw Exception(
        'Invalid environment config: \n${result.errors.format()}',
      );
    }

    final env = result.value;

    return AppConfig._(
      port: env['PORT'] as int,
      databaseUrl: env['DATABASE_URL'] as String,
      redisUrl: env['REDIS_URL'] as String,
      natsUrl: env['NATS_URL'] as String,
      jwtPrivateKeyPath: env['JWT_PRIVATE_KEY_PATH'] as String,
      jwtPublicKeyPath: env['JWT_PUBLIC_KEY_PATH'] as String,
      jwtPrivateKeyPem: env['JWT_PRIVATE_KEY_PEM'] as String,
      jwtPublicKeyPem: env['JWT_PUBLIC_KEY_PEM'] as String,
      jwtAccessTokenExpiry: env['JWT_ACCESS_TOKEN_EXPIRY'] as int,
      jwtRefreshTokenExpiry: env['JWT_REFRESH_TOKEN_EXPIRY'] as int,
      otelEndpoint: env['OTEL_ENDPOINT'] as String,
      environment: env['ENVIRONMENT'] as String,
      maxRequestBodyBytes: env['MAX_REQUEST_BODY_BYTES'] as int,
      dbPoolSize: env['DB_POOL_SIZE'] as int,
      workerCount: env['WORKER_COUNT'] as int,
      initConcurrency: env['INIT_CONCURRENCY'] as int,
    );
  }

  static Map<String, String> _loadDotEnv(String path) {
    final file = File(path);
    if (!file.existsSync()) return const {};

    final vars = <String, String>{};
    for (final rawLine in file.readAsLinesSync()) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      final idx = line.indexOf('=');
      if (idx <= 0) continue;

      final key = line.substring(0, idx).trim();
      var value = line.substring(idx + 1).trim();

      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }

      vars[key] = value;
    }
    return vars;
  }
}
