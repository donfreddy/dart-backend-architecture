import 'package:dart_backend_architecture/core/dto/auth_dto.dart';
import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/core/jwt/jwt_service.dart';
import 'package:dart_backend_architecture/core/logger.dart';
import 'package:dart_backend_architecture/core/password_hasher.dart';
import 'package:dart_backend_architecture/database/model/role.dart';
import 'package:dart_backend_architecture/database/model/user.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/user_repo.dart';
import 'package:dart_backend_architecture/services/token_service.dart';
import 'package:uuid/uuid.dart';

export 'package:dart_backend_architecture/core/dto/auth_dto.dart'
    show LoginDto, SignupDto, AuthResult;

/// Authentication/authorization use-cases: signup, login, logout, token refresh.
///
/// Responsibilities:
///   - Credential validation (email uniqueness, password verification).
///   - User creation and retrieval.
///
/// Token lifecycle (keystore creation/rotation/revocation + JWT issuance) is
/// delegated to [TokenService], keeping this class focused on auth concerns.
class AuthService {
  final UserRepo _userRepo;
  final JwtService _jwt;
  final PasswordHasher _crypto;
  final TokenService _tokenService;
  final Uuid _uuid;

  static final _log = AppLogger.get('AuthService');

  AuthService({
    required UserRepo userRepo,
    required JwtService jwt,
    required PasswordHasher crypto,
    required TokenService tokenService,
    Uuid? uuid,
  })  : _userRepo = userRepo,
        _jwt = jwt,
        _crypto = crypto,
        _tokenService = tokenService,
        _uuid = uuid ?? const Uuid();

  Future<AuthResult> signup(SignupDto dto) async {
    _log.info('Signup attempt: ${dto.email}');

    final existing = await _userRepo.findByEmail(dto.email);
    if (existing != null) {
      throw const BadRequestError('User already registered');
    }

    // Keys are generated here so they can be passed to userRepo.create, which
    // creates user + keystore atomically in a single transaction.
    final accessKey = TokenService.generateKey();
    final refreshKey = TokenService.generateKey();

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
      accessKey,
      refreshKey,
      RoleCode.learner.value,
    );

    final tokens = _tokenService.buildForExistingKeys(
      created.user.id,
      created.keystore.primaryKey,
      created.keystore.secondaryKey,
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

    final tokens = await _tokenService.issue(user);

    _log.info('Login successful: ${user.id}');
    return AuthResult(user: user, tokens: tokens);
  }

  Future<void> logout(String accessToken) async {
    final payload = await _jwt.validate(accessToken);

    final user = await _userRepo.findById(payload.sub);
    if (user == null) {
      throw const AuthFailureError('User not registered');
    }

    await _tokenService.revoke(user: user, primaryKey: payload.prm);
  }

  Future<TokenPair> refreshToken({
    required String accessToken,
    required String refreshToken,
  }) async {
    final accessPayload = await _jwt.decode(accessToken);

    final user = await _userRepo.findById(accessPayload.sub);
    if (user == null) {
      throw const AuthFailureError('User not registered');
    }

    final tokens = await _tokenService.rotate(
      user: user,
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    return tokens;
  }
}
