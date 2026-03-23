import 'dart:convert';

import 'package:dart_backend_architecture/cache/cache_service.dart';
import 'package:dart_backend_architecture/cache/keys.dart';
import 'package:dart_backend_architecture/database/model/keystore.dart';
import 'package:dart_backend_architecture/database/model/user.dart';

final class UserCache {
  final CacheService _cache;

  const UserCache(this._cache);

  // ── Profile ────────────────────────────────────────────────────────────────

  Future<User?> findProfile(String userId) async {
    final raw = await _cache.get(CacheKeys.userProfile(userId));
    if (raw == null) return null;

    try {
      return User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await _cache.invalidate(CacheKeys.userProfile(userId));
      return null;
    }
  }

  Future<void> saveProfile(User user) async {
    await _cache.set(
      CacheKeys.userProfile(user.id),
      jsonEncode(user.toJson()),
      ttl: CacheKeys.userTtl,
    );
  }

  Future<void> evictProfile(String userId) async {
    await _cache.invalidate(CacheKeys.userProfile(userId));
  }

  // ── Keystore ───────────────────────────────────────────────────────────────
  // Cached to avoid a DB round-trip on every authenticated request

  Future<String?> findRefreshToken(String userId) async {
    return _cache.get(CacheKeys.keystore(userId));
  }

  Future<void> saveRefreshToken(String userId, String token) async {
    await _cache.set(
      CacheKeys.keystore(userId),
      token,
      ttl: CacheKeys.keystoreTtl,
    );
  }

  Future<void> evictRefreshToken(String userId) async {
    await _cache.invalidate(CacheKeys.keystore(userId));
  }

  // ── Keystore (per-session) ─────────────────────────────────────────────────
  // Avoids a DB round-trip on every authenticated request.
  // Keyed by (userId, primaryKey) to support multiple concurrent sessions.

  Future<Keystore?> findKeystore(String userId, String primaryKey) async {
    final raw = await _cache.get(CacheKeys.keystoreEntry(userId, primaryKey));
    if (raw == null) return null;

    try {
      return Keystore.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await _cache.invalidate(CacheKeys.keystoreEntry(userId, primaryKey));
      return null;
    }
  }

  Future<void> saveKeystore(String userId, Keystore keystore) async {
    await _cache.set(
      CacheKeys.keystoreEntry(userId, keystore.primaryKey),
      jsonEncode(keystore.toJson()),
      ttl: CacheKeys.keystoreTtl,
    );
  }

  Future<void> evictKeystore(String userId, String primaryKey) async {
    await _cache.invalidate(CacheKeys.keystoreEntry(userId, primaryKey));
  }
}
