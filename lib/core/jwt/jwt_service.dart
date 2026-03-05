import 'dart:io';

import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/core/logger.dart';
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
        'accessToken': accessToken,
        'refreshToken': refreshToken,
      };
}

final class JwtService {
  final String privateKeyPath;
  final String publicKeyPath;
  final Duration accessTokenExpiry;
  final Duration refreshTokenExpiry;

  final _log = AppLogger.get('JwtService');

  late final RSAPrivateKey _privateKey;
  late final RSAPublicKey _publicKey;

  JwtService({
    required this.privateKeyPath,
    required this.publicKeyPath,
    this.accessTokenExpiry = const Duration(hours: 1),
    this.refreshTokenExpiry = const Duration(days: 30),
  }) {
    _loadKeys();
  }

  void _loadKeys() {
    try {
      _privateKey = RSAPrivateKey(File(privateKeyPath).readAsStringSync());
      _publicKey = RSAPublicKey(File(publicKeyPath).readAsStringSync());
    } catch (e) {
      throw const InternalError('Token generation failure');
    }
  }

  String encode(JwtPayload payload) {
    try {
      final jwt = JWT(payload.toMap());
      return jwt.sign(_privateKey);
    } catch (e, st) {
      _log.severe('JWT encode failed', e, st);
      throw const InternalError('Token generation failure');
    }
  }

  JwtPayload validate(String token) {
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

  JwtPayload decode(String token) {
    try {
      final jwt = JWT.verify(
        token,
        _publicKey,
        checkExpiresIn: false,
      );
      return JwtPayload.fromMap(jwt.payload as Map<String, dynamic>);
    } on JWTException catch (e) {
      _log.warning('JWT decode failed: ${e.message}');
      throw const BadTokenError();
    } catch (e, st) {
      _log.severe('Unexpected JWT decode error', e, st);
      throw const BadTokenError();
    }
  }

  // Backward-compatible helpers
  TokenPair issue(JwtPayload payload) {
    return TokenPair(
      accessToken: encode(payload.withValidity(accessTokenExpiry)),
      refreshToken: encode(payload.withValidity(refreshTokenExpiry)),
    );
  }

  JwtPayload verifyAccessToken(String token) => validate(token);

  JwtPayload verifyRefreshToken(String token) => validate(token);

  JwtPayload? extractUnverified(String token) {
    try {
      return decode(token);
    } catch (_) {
      return null;
    }
  }
}
