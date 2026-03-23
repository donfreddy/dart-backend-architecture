import 'dart:io';

import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/core/logger.dart';
import 'package:dart_backend_architecture/workers/jwt_worker.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

final class JwtPayload {
  final String aud;
  final String sub;
  final String iss;
  final int iat;
  final int exp;
  final String prm;

  const JwtPayload({
    required this.aud,
    required this.sub,
    required this.iss,
    required this.iat,
    required this.exp,
    required this.prm,
  });

  factory JwtPayload.create({
    required String issuer,
    required String audience,
    required String subject,
    required String param,
    required Duration validity,
  }) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    return JwtPayload(
      iss: issuer,
      aud: audience,
      sub: subject,
      iat: now,
      exp: now + validity.inSeconds,
      prm: param,
    );
  }

  JwtPayload withValidity(Duration validity) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    return JwtPayload(
      aud: aud,
      sub: sub,
      iss: iss,
      iat: now,
      exp: now + validity.inSeconds,
      prm: prm,
    );
  }

  factory JwtPayload.fromMap(Map<String, dynamic> map) {
    int readInt(String key) {
      final value = map[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      throw BadTokenError('Invalid token payload: missing $key');
    }

    return JwtPayload(
      aud: map['aud'] as String,
      sub: map['sub'] as String,
      iss: map['iss'] as String,
      iat: readInt('iat'),
      exp: readInt('exp'),
      prm: map['prm'] as String,
    );
  }

  Map<String, dynamic> toMap() => {
        'aud': aud,
        'sub': sub,
        'iss': iss,
        'iat': iat,
        'exp': exp,
        'prm': prm,
      };
}

final class TokenPair {
  final String accessToken;
  final String refreshToken;

  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
  });

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
      };
}

final _log = AppLogger.get('JwtService');

/// JWT encoding / decoding service.
///
/// - [encode] signs tokens with the RSA private key (sync, called rarely).
/// - [validate] and [decode] verify tokens via a [JwtWorker] isolate when
///   available, keeping RSA CPU work off the HTTP event loop.
///
/// Call [initWorker] after construction to enable isolate-based verification.
/// Call [dispose] on graceful shutdown to kill the worker isolate.
class JwtService {
  final String privateKeyPath;
  final String publicKeyPath;
  final String privateKeyPem;
  final String publicKeyPem;
  final Duration accessTokenExpiry;
  final Duration refreshTokenExpiry;

  late final RSAPrivateKey _privateKey;
  late final RSAPublicKey _publicKey;
  late final String _publicKeyPem;

  JwtWorker? _worker;

  JwtService({
    this.privateKeyPath = '',
    this.publicKeyPath = '',
    this.privateKeyPem = '',
    this.publicKeyPem = '',
    this.accessTokenExpiry = const Duration(hours: 1),
    this.refreshTokenExpiry = const Duration(days: 30),
  }) {
    _loadKeys();
  }

  /// Resolves keys in priority order: inline PEM → file path.
  /// Throws [InternalError] if neither source is provided or readable.
  void _loadKeys() {
    try {
      final privatePem = privateKeyPem.isNotEmpty
          ? privateKeyPem
          : File(privateKeyPath).readAsStringSync();
      _publicKeyPem = publicKeyPem.isNotEmpty
          ? publicKeyPem
          : File(publicKeyPath).readAsStringSync();
      _privateKey = RSAPrivateKey(privatePem);
      _publicKey = RSAPublicKey(_publicKeyPem);
    } catch (e) {
      throw const InternalError('Token generation failure');
    }
  }

  /// Spawn the [JwtWorker] isolate. Should be called once at startup.
  Future<void> initWorker() async {
    _worker = await JwtWorker.spawn(_publicKeyPem);
    _log.info('JwtService: worker isolate active');
  }

  /// Kill the worker isolate. Call on graceful shutdown.
  Future<void> dispose() async {
    await _worker?.dispose();
    _worker = null;
  }

  // ── Encoding (sync: uses private key, called only on login/signup) ────────

  String encode(JwtPayload payload) {
    try {
      final jwt = JWT(payload.toMap());
      return jwt.sign(_privateKey);
    } catch (e, st) {
      _log.severe('JWT encode failed', e, st);
      throw const InternalError('Token generation failure');
    }
  }

  // ── Verification (async: delegates to worker isolate when available) ──────

  /// Verify [token] signature and expiry.
  /// Throws [TokenExpiredError] or [BadTokenError] on failure.
  Future<JwtPayload> validate(String token) async {
    if (_worker != null) {
      final map = await _worker!.validate(token);
      return JwtPayload.fromMap(map);
    }
    return _validateSync(token);
  }

  /// Decode [token] without checking expiry.
  /// Throws [BadTokenError] on structural failures.
  Future<JwtPayload> decode(String token) async {
    if (_worker != null) {
      final map = await _worker!.decode(token);
      return JwtPayload.fromMap(map);
    }
    return _decodeSync(token);
  }

  // ── Sync fallbacks (used when worker not yet initialised / in tests) ───────

  JwtPayload _validateSync(String token) {
    try {
      final jwt = JWT.verify(token, _publicKey);
      return JwtPayload.fromMap(jwt.payload as Map<String, dynamic>);
    } on JWTExpiredException {
      throw const TokenExpiredError();
    } on JWTException catch (e) {
      _log.warning('JWT validate failed: ${e.message}');
      throw const BadTokenError();
    } catch (e, st) {
      _log.severe('Unexpected JWT validation error', e, st);
      throw const BadTokenError();
    }
  }

  JwtPayload _decodeSync(String token) {
    try {
      final jwt = JWT.verify(token, _publicKey, checkExpiresIn: false);
      return JwtPayload.fromMap(jwt.payload as Map<String, dynamic>);
    } on JWTException catch (e) {
      _log.warning('JWT decode failed: ${e.message}');
      throw const BadTokenError();
    } catch (e, st) {
      _log.severe('Unexpected JWT decode error', e, st);
      throw const BadTokenError();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  TokenPair issue(JwtPayload payload) {
    return TokenPair(
      accessToken: encode(payload.withValidity(accessTokenExpiry)),
      refreshToken: encode(payload.withValidity(refreshTokenExpiry)),
    );
  }

  Future<JwtPayload> verifyAccessToken(String token) => validate(token);
  Future<JwtPayload> verifyRefreshToken(String token) => validate(token);

  Future<JwtPayload?> extractUnverified(String token) async {
    try {
      return await decode(token);
    } catch (_) {
      return null;
    }
  }
}
