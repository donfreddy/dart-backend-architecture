import 'package:dart_backend_architecture/core/circuit_breaker.dart';
import 'package:dart_backend_architecture/core/logger.dart';
import 'package:postgres/postgres.dart';

/// Thin wrapper around `postgres.Pool` with sane defaults and validation.
final class DatabasePool {
  final Pool<dynamic> _pool;
  final CircuitBreaker _breaker =
      CircuitBreaker(name: 'PostgreSQL', failureThreshold: 5);

  DatabasePool._(this._pool);

  static Future<DatabasePool> connect(
    String databaseUrl, {
    int maxConnections = 20,
  }) async {
    final log = AppLogger.get('DatabasePool');

    final uri = Uri.parse(databaseUrl);
    final database = uri.path.replaceFirst('/', '');
    final port = uri.hasPort ? uri.port : 5432;
    final sslMode = uri.queryParameters['sslmode'] == 'disable'
        ? SslMode.disable
        : SslMode.require;
    final credentials = _parseCredentials(uri);

    if (uri.host.isEmpty || database.isEmpty) {
      throw ArgumentError.value(
        databaseUrl,
        'databaseUrl',
        'Invalid PostgreSQL URL: host and database are required',
      );
    }

    final pool = Pool<dynamic>.withEndpoints(
      [
        Endpoint(
          host: uri.host,
          port: port,
          database: database,
          username: credentials.$1,
          password: credentials.$2,
        ),
      ],
      settings: PoolSettings(
        maxConnectionCount: maxConnections,
        connectTimeout: const Duration(seconds: 5),
        queryTimeout: const Duration(seconds: 5),
        sslMode: sslMode,
      ),
    );

    // Verify connectivity at startup, fail fast
    await pool.execute('SELECT 1');
    log.info('PostgreSQL connected -> ${uri.host}:$port/$database');

    return DatabasePool._(pool);
  }

  /// Run a query through the circuit breaker.
  Future<Result> execute(
    Object sql, {
    Map<String, dynamic>? parameters,
  }) {
    return _breaker.execute(() => _pool.execute(sql, parameters: parameters));
  }

  /// Run a transaction through the circuit breaker.
  Future<T> runTx<T>(Future<T> Function(Session session) action) {
    return _breaker.execute(() => _pool.runTx(action));
  }

  Future<void> close() async {
    await _pool.close();
    AppLogger.get('DatabasePool').info('PostgreSQL pool closed');
  }
}

(String, String) _parseCredentials(Uri uri) {
  final userInfo = uri.userInfo;
  final separator = userInfo.indexOf(':');
  if (separator <= 0 || separator == userInfo.length - 1) {
    throw ArgumentError.value(
      uri.toString(),
      'databaseUrl',
      'Invalid PostgreSQL URL: username and password are required',
    );
  }

  final username = Uri.decodeComponent(userInfo.substring(0, separator));
  final password = Uri.decodeComponent(userInfo.substring(separator + 1));
  return (username, password);
}
