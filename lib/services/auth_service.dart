import 'dart:math';

import 'package:dart_backend_architecture/cache/repository/user_cache.dart';
import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/core/jwt/jwt_service.dart';
import 'package:dart_backend_architecture/core/logger.dart';
import 'package:dart_backend_architecture/database/model/role.dart';
import 'package:dart_backend_architecture/database/model/user.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/keystore_repo.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/user_repo.dart';
import 'package:dart_backend_architecture/workers/crypto_worker.dart';
import 'package:uuid/uuid.dart';

/// Authentication/authorization use-cases (signup, login, refresh, logout).
/// Stateless tokens with per-user keystore; delegates hashing to CryptoWorker.
final class LoginDto {
  final String email;
  final String password;

  const LoginDto({required this.email, required this.password});

  factory LoginDto.fromJson(Map<String, dynamic> json) => LoginDto(
        email: json['email'] as String,
        password: json['password'] as String,
      );
}

final class SignupDto {
  final String name;
  final String email;
  final String password;
  final String? profilePicUrl;

  const SignupDto({
    required this.name,
    required this.email,
    required this.password,
    this.profilePicUrl,
  });

  factory SignupDto.fromJson(Map<String, dynamic> json) => SignupDto(
        name: json['name'] as String,
        email: json['email'] as String,
        password: json['password'] as String,
        profilePicUrl: json['profilePicUrl'] as String?,
      );
}

final class AuthResult {
  final User user;
  final TokenPair tokens;

  const AuthResult({required this.user, required this.tokens});

  Map<String, dynamic> toJson() => {
        'user': {
          'id': user.id,
          'name': user.name,
          'email': user.email,
          'roles': user.roles,
          if (user.profilePicUrl != null) 'profilePicUrl': user.profilePicUrl,
        },
        'tokens': tokens.toJson(),
      };
}

class AuthService {
  final UserRepo _userRepo;
  final KeystoreRepo _keystoreRepo;
  final JwtService _jwt;
  final CryptoWorker _crypto;
  final UserCache? _userCache;
  final Uuid _uuid;
  final String _issuer;
  final String _audience;

  static final _log = AppLogger.get('AuthService');

  AuthService({
    required UserRepo userRepo,
    required KeystoreRepo keystoreRepo,
    required JwtService jwt,
    required CryptoWorker crypto,
    UserCache? userCache,
    Uuid? uuid,
    String issuer = 'dart-backend-architecture',
    String audience = 'dba-users',
  })  : _userRepo = userRepo,
        _keystoreRepo = keystoreRepo,
        _jwt = jwt,
        _crypto = crypto,
        _userCache = userCache,
        _uuid = uuid ?? const Uuid(),
        _issuer = issuer,
        _audience = audience;

  Future<AuthResult> signup(SignupDto dto) async {
    _log.info('Signup attempt: ${dto.email}');

    final existing = await _userRepo.findByEmail(dto.email);
    if (existing != null) {
      throw const BadRequestError('User already registered');
    }

    final accessTokenKey = _randomHex(64);
    final refreshTokenKey = _randomHex(64);

    final user = User(
      id: _uuid.v4(),
      email: dto.email,
      name: dto.name,
      passwordHash: await _crypto.hashPassword(dto.password),
      profilePicUrl: dto.profilePicUrl,
      createdAt: DateTime.now().toUtc(),
    );

    final created = await _userRepo.create(
      user,
      accessTokenKey,
      refreshTokenKey,
      RoleCode.learner.value,
    );

    final tokens = _createTokens(
      userId: created.user.id,
      accessTokenKey: created.keystore.primaryKey,
      refreshTokenKey: created.keystore.secondaryKey,
    );

    _log.info('Signup successful: ${created.user.id}');
    return AuthResult(user: created.user, tokens: tokens);
  }

  Future<AuthResult> login(LoginDto dto) async {
    _log.info('Login attempt: ${dto.email}');

    final user = await _userRepo.findByEmail(dto.email);
    if (user == null) {
      throw const BadRequestError('User not registered');
    }

    final passwordHash = user.passwordHash;
    if (passwordHash == null || passwordHash.isEmpty) {
      throw const BadRequestError('Credential not set');
    }
    if (!await _crypto.verifyPassword(dto.password, passwordHash)) {
      throw const AuthFailureError('Authentication failure');
    }

    final accessTokenKey = _randomHex(64);
    final refreshTokenKey = _randomHex(64);
    await _keystoreRepo.create(user, accessTokenKey, refreshTokenKey);

    final tokens = _createTokens(
      userId: user.id,
      accessTokenKey: accessTokenKey,
      refreshTokenKey: refreshTokenKey,
    );

    _log.info('Login successful: ${user.id}');
    return AuthResult(user: user, tokens: tokens);
  }

  Future<void> logout(String accessToken) async {
    final payload = _jwt.validate(accessToken);

    final user = await _userRepo.findById(payload.sub);
    if (user == null) {
      throw const AuthFailureError('User not registered');
    }

    final keystore = await _keystoreRepo.findForKey(user, payload.prm);
    if (keystore?.id == null) {
      throw const AuthFailureError('Invalid access token');
    }

    await _keystoreRepo.remove(keystore!.id!);
    // Evict cached keystore so subsequent requests with the same token
    // are rejected immediately rather than after the TTL expires.
    await _userCache?.evictKeystore(user.id, payload.prm);
  }

  Future<TokenPair> refreshToken({
    required String accessToken,
    required String refreshToken,
  }) async {
    final accessPayload = _jwt.decode(accessToken);
    final user = await _userRepo.findById(accessPayload.sub);
    if (user == null) {
      throw const AuthFailureError('User not registered');
    }

    final refreshPayload = _jwt.validate(refreshToken);
    if (accessPayload.sub != refreshPayload.sub) {
      throw const AuthFailureError('Invalid access token');
    }

    final currentKeystore = await _keystoreRepo.find(
      user,
      accessPayload.prm,
      refreshPayload.prm,
    );
    if (currentKeystore?.id == null) {
      throw const AuthFailureError('Invalid access token');
    }

    // Remove old keystore from DB and cache before creating the new one.
    await _keystoreRepo.remove(currentKeystore!.id!);
    await _userCache?.evictKeystore(user.id, accessPayload.prm);

    final nextAccessTokenKey = _randomHex(64);
    final nextRefreshTokenKey = _randomHex(64);
    await _keystoreRepo.create(user, nextAccessTokenKey, nextRefreshTokenKey);

    return _createTokens(
      userId: user.id,
      accessTokenKey: nextAccessTokenKey,
      refreshTokenKey: nextRefreshTokenKey,
    );
  }

  TokenPair _createTokens({
    required String userId,
    required String accessTokenKey,
    required String refreshTokenKey,
  }) {
    final accessPayload = JwtPayload.create(
      issuer: _issuer,
      audience: _audience,
      subject: userId,
      param: accessTokenKey,
      validity: _jwt.accessTokenExpiry,
    );

    final refreshPayload = JwtPayload.create(
      issuer: _issuer,
      audience: _audience,
      subject: userId,
      param: refreshTokenKey,
      validity: _jwt.refreshTokenExpiry,
    );

    return TokenPair(
      accessToken: _jwt.encode(accessPayload),
      refreshToken: _jwt.encode(refreshPayload),
    );
  }

  static String _randomHex(int bytesLength) {
    const chars = '0123456789abcdef';
    final random = Random.secure();
    final codeUnits = List<int>.generate(
      bytesLength * 2,
      (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      growable: false,
    );
    return String.fromCharCodes(codeUnits);
  }
}
