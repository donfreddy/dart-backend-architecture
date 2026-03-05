import 'package:dart_backend_architecture/core/logger.dart';
import 'package:redis/redis.dart';

final _log = AppLogger.get('CacheService');

final class CacheService {
  final Command _cmd;

  CacheService._(this._cmd);

  static Future<CacheService> connect(String redisUrl) async {
    final uri = Uri.parse(redisUrl);
    final port = uri.hasPort ? uri.port : 6379;
    final dbIndex = _parseDbIndex(uri);
    final conn = RedisConnection();
    final cmd = await conn.connect(uri.host, port);

    if (uri.host.isEmpty) {
      throw ArgumentError.value(
        redisUrl,
        'redisUrl',
        'Invalid Redis URL: host is required',
      );
    }

    // Auth if password provided
    final password = _parsePassword(uri);
    if (password != null && password.isNotEmpty) {
      await cmd.send_object(['AUTH', password]);
    }

    if (dbIndex != 0) {
      await cmd.send_object(['SELECT', dbIndex]);
    }

    // Verify connectivity
    await cmd.send_object(['PING']);
    _log.info('Redis connected -> ${uri.host}:$port/$dbIndex');

    return CacheService._(cmd);
  }

  // ── Core operations ───────────────────────────────────────────

  Future<String?> get(String key) async {
    try {
      final result = await _cmd.send_object(['GET', key]);
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
      await _cmd.send_object(['SET', key, value, 'EX', ttl.inSeconds]);
    } catch (e) {
      _log.warning('Cache SET failed for key $key: $e');
    }
  }

  Future<void> invalidate(String key) async {
    try {
      await _cmd.send_object(['DEL', key]);
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
        final result = await _cmd.send_object(['SCAN', cursor, 'MATCH', pattern, 'COUNT', 200]);
        final parts = result as List<dynamic>;
        cursor = parts.first.toString();
        final keys = (parts[1] as List<dynamic>).cast<String>();
        if (keys.isEmpty) continue;

        await _cmd.send_object(['DEL', ...keys]);
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
      final result = await _cmd.send_object(['INCR', key]);
      final count = switch (result) {
        final int value => value,
        final String value => int.parse(value),
        final num value => value.toInt(),
        _ => throw StateError('Unexpected INCR response type: ${result.runtimeType}'),
      };

      // Set TTL only on first increment — avoids resetting the window
      if (count == 1) {
        await _cmd.send_object(['EXPIRE', key, window.inSeconds]);
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
