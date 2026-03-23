import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/core/jwt/jwt_service.dart';
import 'package:dart_backend_architecture/database/model/keystore.dart';
import 'package:dart_backend_architecture/database/model/user.dart';
import 'package:dart_backend_architecture/services/auth_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import '../../mocks/mocks.dart';

void main() {
  const accessPayload = JwtPayload(
    aud: 'aud',
    sub: 'u-1',
    iss: 'iss',
    iat: 0,
    exp: 1,
    prm: 'access-key',
  );

  final user = User(
    id: 'u-1',
    email: 'x@y.com',
    name: 'X',
    passwordHash: 'bcrypt-hash',
    createdAt: DateTime.utc(2026, 1, 1),
  );

  const tokenPair = TokenPair(
    accessToken: 'access-jwt',
    refreshToken: 'refresh-jwt',
  );

  setUpAll(() {
    registerFallbackValue(
      User(
        id: 'fallback',
        email: 'fallback@example.com',
        name: 'fallback',
        createdAt: DateTime.utc(2024, 1, 1),
      ),
    );
  });

  AuthService buildSut({
    MockUserRepo? userRepo,
    MockJwtService? jwt,
    MockCryptoWorker? crypto,
    MockTokenService? tokenService,
  }) =>
      AuthService(
        userRepo: userRepo ?? MockUserRepo(),
        jwt: jwt ?? MockJwtService(),
        crypto: crypto ?? MockCryptoWorker(),
        tokenService: tokenService ?? MockTokenService(),
      );

  // ── login ──────────────────────────────────────────────────────────────────

  group('AuthService.login', () {
    late MockUserRepo mockUserRepo;
    late MockCryptoWorker mockCrypto;
    late MockTokenService mockTokenService;
    late AuthService sut;

    setUp(() {
      mockUserRepo = MockUserRepo();
      mockCrypto = MockCryptoWorker();
      mockTokenService = MockTokenService();
      sut = buildSut(
        userRepo: mockUserRepo,
        crypto: mockCrypto,
        tokenService: mockTokenService,
      );
    });

    test('throws BadRequestError when user not found', () async {
      when(() => mockUserRepo.findByEmail(any())).thenAnswer((_) async => null);

      await expectLater(
        sut.login(const LoginDto(email: 'x@y.com', password: 'pass')),
        throwsA(isA<BadRequestError>()),
      );
    });

    test('throws AuthFailureError on wrong password', () async {
      when(() => mockUserRepo.findByEmail(any())).thenAnswer((_) async => user);
      when(() => mockCrypto.verifyPassword(any(), any()))
          .thenAnswer((_) async => false);

      await expectLater(
        sut.login(const LoginDto(email: 'x@y.com', password: 'wrong')),
        throwsA(isA<AuthFailureError>()),
      );
    });

    test('returns AuthResult on valid credentials', () async {
      when(() => mockUserRepo.findByEmail('x@y.com'))
          .thenAnswer((_) async => user);
      when(() => mockCrypto.verifyPassword('pass123', user.passwordHash!))
          .thenAnswer((_) async => true);
      when(() => mockTokenService.issue(user))
          .thenAnswer((_) async => tokenPair);

      final result = await sut
          .login(const LoginDto(email: 'x@y.com', password: 'pass123'));

      expect(result.user.id, 'u-1');
      expect(result.tokens.accessToken, 'access-jwt');
      verify(() => mockCrypto.verifyPassword('pass123', user.passwordHash!))
          .called(1);
      verify(() => mockTokenService.issue(user)).called(1);
    });
  });

  // ── signup ─────────────────────────────────────────────────────────────────

  group('AuthService.signup', () {
    late MockUserRepo mockUserRepo;
    late MockCryptoWorker mockCrypto;
    late MockTokenService mockTokenService;
    late AuthService sut;

    final newUser = User(
      id: 'u-2',
      email: 'new@y.com',
      name: 'New',
      passwordHash: 'hashed',
      createdAt: DateTime.utc(2026, 1, 1),
    );

    setUp(() {
      mockUserRepo = MockUserRepo();
      mockCrypto = MockCryptoWorker();
      mockTokenService = MockTokenService();
      sut = buildSut(
        userRepo: mockUserRepo,
        crypto: mockCrypto,
        tokenService: mockTokenService,
      );
    });

    test('throws BadRequestError when user already exists', () async {
      when(() => mockUserRepo.findByEmail(any()))
          .thenAnswer((_) async => newUser);

      await expectLater(
        sut.signup(
          const SignupDto(name: 'X', email: 'new@y.com', password: 'p'),
        ),
        throwsA(isA<BadRequestError>()),
      );
    });

    test('creates user, hashes password, returns tokens', () async {
      when(() => mockUserRepo.findByEmail(any())).thenAnswer((_) async => null);
      when(() => mockCrypto.hashPassword(any()))
          .thenAnswer((inv) async => 'hashed-${inv.positionalArguments.first}');
      when(() => mockUserRepo.create(any(), any(), any(), any())).thenAnswer(
        (inv) async => (
          user: newUser,
          keystore: Keystore(
            id: 'k1',
            client: newUser,
            primaryKey: 'pk',
            secondaryKey: 'sk',
          ),
        ),
      );
      when(() => mockTokenService.buildForExistingKeys(any(), any(), any()))
          .thenReturn(tokenPair);

      final result = await sut.signup(
        const SignupDto(name: 'X', email: 'new@y.com', password: 'p'),
      );

      expect(result.user.email, 'new@y.com');
      expect(result.tokens.accessToken, 'access-jwt');
      verify(() => mockCrypto.hashPassword('p')).called(1);
      verify(() => mockUserRepo.create(any(), any(), any(), any())).called(1);
      verify(() => mockTokenService.buildForExistingKeys(any(), any(), any()))
          .called(1);
    });
  });

  // ── logout ─────────────────────────────────────────────────────────────────

  group('AuthService.logout', () {
    late MockUserRepo mockUserRepo;
    late MockJwtService mockJwt;
    late MockTokenService mockTokenService;
    late AuthService sut;

    setUp(() {
      mockUserRepo = MockUserRepo();
      mockJwt = MockJwtService();
      mockTokenService = MockTokenService();
      sut = buildSut(
        userRepo: mockUserRepo,
        jwt: mockJwt,
        tokenService: mockTokenService,
      );
    });

    test('delegates revoke to TokenService for valid access token', () async {
      when(() => mockJwt.validate('access'))
          .thenAnswer((_) async => accessPayload);
      when(() => mockUserRepo.findById('u-1')).thenAnswer((_) async => user);
      when(() => mockTokenService.revoke(user: user, primaryKey: 'access-key'))
          .thenAnswer((_) async {});

      await sut.logout('access');

      verify(
        () => mockTokenService.revoke(user: user, primaryKey: 'access-key'),
      ).called(1);
    });

    test('throws AuthFailureError when user not found', () async {
      when(() => mockJwt.validate('access'))
          .thenAnswer((_) async => accessPayload);
      when(() => mockUserRepo.findById('u-1')).thenAnswer((_) async => null);

      await expectLater(
        sut.logout('access'),
        throwsA(isA<AuthFailureError>()),
      );
    });
  });

  // ── refreshToken ───────────────────────────────────────────────────────────

  group('AuthService.refreshToken', () {
    late MockUserRepo mockUserRepo;
    late MockJwtService mockJwt;
    late MockTokenService mockTokenService;
    late AuthService sut;

    setUp(() {
      mockUserRepo = MockUserRepo();
      mockJwt = MockJwtService();
      mockTokenService = MockTokenService();
      sut = buildSut(
        userRepo: mockUserRepo,
        jwt: mockJwt,
        tokenService: mockTokenService,
      );
    });

    test('delegates rotation to TokenService', () async {
      when(() => mockJwt.decode('access'))
          .thenAnswer((_) async => accessPayload);
      when(() => mockUserRepo.findById('u-1')).thenAnswer((_) async => user);
      when(
        () => mockTokenService.rotate(
          user: user,
          accessToken: 'access',
          refreshToken: 'refresh',
        ),
      ).thenAnswer((_) async => tokenPair);

      final tokens = await sut.refreshToken(
        accessToken: 'access',
        refreshToken: 'refresh',
      );

      expect(tokens.accessToken, 'access-jwt');
      verify(
        () => mockTokenService.rotate(
          user: user,
          accessToken: 'access',
          refreshToken: 'refresh',
        ),
      ).called(1);
    });

    test('throws AuthFailureError when user not found', () async {
      when(() => mockJwt.decode('access'))
          .thenAnswer((_) async => accessPayload);
      when(() => mockUserRepo.findById('u-1')).thenAnswer((_) async => null);

      await expectLater(
        sut.refreshToken(accessToken: 'access', refreshToken: 'refresh'),
        throwsA(isA<AuthFailureError>()),
      );
    });
  });
}
