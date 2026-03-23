import 'dart:math';

import 'package:dart_backend_architecture/cache/repository/user_cache.dart';
import 'package:dart_backend_architecture/core/app_info.dart';
import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/core/jwt/jwt_service.dart';
import 'package:dart_backend_architecture/database/model/user.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/keystore_repo.dart';

/// Manages the full token lifecycle: issuance, rotation, and revocation.
///
/// Extracted from [AuthService] so that JWT + keystore concerns live in one
/// place and [AuthService] can focus solely on credential verification and
/// user management.
///
/// All methods are async because [JwtService.validate] and [decode] delegate
/// to the [JwtWorker] isolate.
class TokenService {
  final KeystoreRepo _keystoreRepo;
  final JwtService _jwt;
  final UserCache? _userCache;
  final String _issuer;
  final String _audience;

  TokenService({
    required KeystoreRepo keystoreRepo,
    required JwtService jwt,
    UserCache? userCache,
    String issuer = AppInfo.name,
    String audience = 'dba-users',
  })  : _keystoreRepo = keystoreRepo,
        _jwt = jwt,
        _userCache = userCache,
        _issuer = issuer,
        _audience = audience;

  // ── Issuance ──────────────────────────────────────────────────────────────

  /// Create a new keystore entry and issue a fresh [TokenPair] (login flow).
  Future<TokenPair> issue(User user) async {
    final accessKey = generateKey();
    final refreshKey = generateKey();
    await _keystoreRepo.create(user, accessKey, refreshKey);
    return _buildTokenPair(user.id, accessKey, refreshKey);
  }

  /// Issue a [TokenPair] from pre-existing keys without touching the keystore
  /// (signup flow: [UserRepo.create] already persisted keystore atomically).
  TokenPair buildForExistingKeys(
    String userId,
    String accessKey,
    String refreshKey,
  ) =>
      _buildTokenPair(userId, accessKey, refreshKey);

  // ── Revocation ─────────────────────────────────────────────────────────────

  /// Remove a keystore entry and evict its cache entry (logout flow).
  /// Throws [AuthFailureError] if no matching keystore is found.
  Future<void> revoke({
    required User user,
    required String primaryKey,
  }) async {
    final keystore = await _keystoreRepo.findForKey(user, primaryKey);
    if (keystore?.id == null) {
      throw const AuthFailureError('Invalid access token');
    }
    await _keystoreRepo.remove(keystore!.id!);
    await _userCache?.evictKeystore(user.id, primaryKey);
  }

  // ── Rotation ───────────────────────────────────────────────────────────────

  /// Validate both tokens, revoke the current keystore, and issue fresh tokens
  /// (refresh flow). Throws [AuthFailureError] on any mismatch.
  Future<TokenPair> rotate({
    required User user,
    required String accessToken,
    required String refreshToken,
  }) async {
    final accessPayload = await _jwt.decode(accessToken);
    final refreshPayload = await _jwt.validate(refreshToken);

    if (accessPayload.sub != refreshPayload.sub) {
      throw const AuthFailureError('Invalid access token');
    }

    final current = await _keystoreRepo.find(
      user,
      accessPayload.prm,
      refreshPayload.prm,
    );
    if (current?.id == null) {
      throw const AuthFailureError('Invalid access token');
    }

    await _keystoreRepo.remove(current!.id!);
    await _userCache?.evictKeystore(user.id, accessPayload.prm);

    return issue(user);
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  TokenPair _buildTokenPair(
    String userId,
    String accessKey,
    String refreshKey,
  ) {
    final accessPayload = JwtPayload.create(
      issuer: _issuer,
      audience: _audience,
      subject: userId,
      param: accessKey,
      validity: _jwt.accessTokenExpiry,
    );
    final refreshPayload = JwtPayload.create(
      issuer: _issuer,
      audience: _audience,
      subject: userId,
      param: refreshKey,
      validity: _jwt.refreshTokenExpiry,
    );
    return TokenPair(
      accessToken: _jwt.encode(accessPayload),
      refreshToken: _jwt.encode(refreshPayload),
    );
  }

  static String generateKey() {
    const chars = '0123456789abcdef';
    final rng = Random.secure();
    return String.fromCharCodes(
      List.generate(128, (_) => chars.codeUnitAt(rng.nextInt(chars.length))),
    );
  }
}
