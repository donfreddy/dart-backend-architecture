import 'dart:async';

import 'package:dart_backend_architecture/core/logger.dart';
import 'package:redis/redis.dart';

final _log = AppLogger.get('CacheService');

final class CacheService {
  final _RedisConfig _config;
  late RedisConnection _conn;
  late Command _cmd;
  Completer<void>? _reconnectCompleter;

  CacheService._(this._config, this._conn, this._cmd);

  static Future<CacheService> connect(String redisUrl) async {
    final config = _RedisConfig.parse(redisUrl);
    final conn = RedisConnection();
    final cmd = await _open(config, conn);
    return CacheService._(config, conn, cmd);
  }

  // ── Core operations ───────────────────────────────────────────

  Future<String?> get(String key) async {
    try {
      final result = await _execute((cmd) => cmd.send_object(['GET', key]));
      return result as String?;
    } catch (e) {
      _log.warning('Cache GET failed for key $key: $e');
      return null; // Graceful degradation
    }
  }

  Future<void> set(
    String key,
    String value, {
    Duration ttl = const Duration(minutes: 15),
  }) async {
    try {
      await _execute((cmd) => cmd.send_object(['SET', key, value, 'EX', ttl.inSeconds]));
    } catch (e) {
      _log.warning('Cache SET failed for key $key: $e');
    }
  }

  Future<void> invalidate(String key) async {
    try {
      await _execute((cmd) => cmd.send_object(['DEL', key]));
    } catch (e) {
      _log.warning('Cache DEL failed for key $key: $e');
    }
  }

  // Invalidate all keys matching a pattern — use with care on large datasets
  Future<void> invalidatePattern(String pattern) async {
    try {
      var cursor = '0';
      var removed = 0;

      do {
        final result = await _execute((cmd) => cmd.send_object(['SCAN', cursor, 'MATCH', pattern, 'COUNT', 200]));
        final parts = result as List<dynamic>;
        cursor = parts.first.toString();
        final keys = (parts[1] as List<dynamic>).cast<String>();
        if (keys.isEmpty) continue;

        await _execute((cmd) => cmd.send_object(['DEL', ...keys]));
        removed += keys.length;
      } while (cursor != '0');

      if (removed > 0) {
        _log.info('Invalidated $removed key(s) matching $pattern');
      }
    } catch (e) {
      _log.warning('Cache pattern invalidation failed for $pattern: $e');
    }
  }

  // Atomic increment with TTL — used by rate limiter
  Future<int> increment(String key, {required Duration window}) async {
    try {
      final result = await _execute((cmd) => cmd.send_object(['INCR', key]));
      final count = switch (result) {
        final int value => value,
        final String value => int.parse(value),
        final num value => value.toInt(),
        _ => throw StateError('Unexpected INCR response type: ${result.runtimeType}'),
      };

      // Set TTL only on first increment — avoids resetting the window
      if (count == 1) {
        await _execute((cmd) => cmd.send_object(['EXPIRE', key, window.inSeconds]));
      }

      return count;
    } catch (e) {
      _log.warning('Cache INCR failed for key $key: $e');
      return 0; // Fail open — never block a request due to Redis failure
    }
  }

  // ── Cache-aside pattern ───────────────────────────────────────

  Future<T> getOrSet<T>(
    String key,
    Future<T> Function() loader,
    String Function(T) serialize,
    T Function(String) deserialize, {
    Duration ttl = const Duration(minutes: 15),
  }) async {
    // 1. Try cache
    final cached = await get(key);
    if (cached != null) {
      try {
        return deserialize(cached);
      } catch (e) {
        // Corrupt cache entry — evict and reload
        _log.warning('Failed to deserialize cache entry for $key — evicting');
        await invalidate(key);
      }
    }

    // 2. Load from source
    final value = await loader();

    // 3. Populate cache — never throws
    await set(key, serialize(value), ttl: ttl);

    return value;
  }

  Future<void> close() async {
    try {
      await _cmd.send_object(['QUIT']);
    } catch (_) {}
    _log.info('Redis connection closed');
  }

  Future<bool> ping() async {
    try {
      await _execute((cmd) => cmd.send_object(['PING']));
      return true;
    } catch (e) {
      _log.warning('Redis PING failed: $e');
      return false;
    }
  }

  // ── Connection management ─────────────────────────────────────

  Future<T> _execute<T>(Future<T> Function(Command cmd) action) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await action(_cmd);
      } catch (e) {
        _log.warning('Redis command failed (attempt ${attempt + 1}) — reconnecting: $e');
        await _reconnect();
      }
    }
    // Last attempt — let the error surface
    return action(_cmd);
  }

  Future<void> _reconnect() async {
    // Deduplicate concurrent reconnects
    if (_reconnectCompleter != null) {
      return _reconnectCompleter!.future;
    }
    final completer = _reconnectCompleter = Completer<void>();

    try {
      try {
        await _cmd.send_object(['QUIT']);
      } catch (_) {}

      _conn = RedisConnection();
      _cmd = await _open(_config, _conn);
      _log.info('Redis reconnected -> ${_config.host}:${_config.port}/${_config.dbIndex}');
      completer.complete();
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _reconnectCompleter = null;
    }
  }

  static Future<Command> _open(_RedisConfig config, RedisConnection conn) async {
    if (config.host.isEmpty) {
      throw ArgumentError.value(
        config.rawUrl,
        'redisUrl',
        'Invalid Redis URL: host is required',
      );
    }

    final cmd = await conn.connect(config.host, config.port);

    if (config.password != null && config.password!.isNotEmpty) {
      await cmd.send_object(['AUTH', config.password]);
    }

    if (config.dbIndex != 0) {
      await cmd.send_object(['SELECT', config.dbIndex]);
    }

    await cmd.send_object(['PING']);
    _log.info('Redis connected -> ${config.host}:${config.port}/${config.dbIndex}');
    return cmd;
  }
}

String? _parsePassword(Uri uri) {
  final userInfo = uri.userInfo;
  if (userInfo.isEmpty) return null;

  final separator = userInfo.indexOf(':');
  if (separator < 0) return null;

  final raw = userInfo.substring(separator + 1);
  if (raw.isEmpty) return null;
  return Uri.decodeComponent(raw);
}

int _parseDbIndex(Uri uri) {
  final path = uri.path.replaceFirst('/', '');
  if (path.isEmpty) return 0;
  return int.tryParse(path) ?? 0;
}

final class _RedisConfig {
  final String rawUrl;
  final String host;
  final int port;
  final int dbIndex;
  final String? password;

  const _RedisConfig({
    required this.rawUrl,
    required this.host,
    required this.port,
    required this.dbIndex,
    required this.password,
  });

  factory _RedisConfig.parse(String redisUrl) {
    final uri = Uri.parse(redisUrl);
    final port = uri.hasPort ? uri.port : 6379;
    final dbIndex = _parseDbIndex(uri);
    final password = _parsePassword(uri);

    return _RedisConfig(
      rawUrl: redisUrl,
      host: uri.host,
      port: port,
      dbIndex: dbIndex,
      password: password,
    );
  }
}
