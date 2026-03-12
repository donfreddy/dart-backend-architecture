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

  const refreshPayload = JwtPayload(
    aud: 'aud',
    sub: 'u-1',
    iss: 'iss',
    iat: 0,
    exp: 2,
    prm: 'refresh-key',
  );

  setUpAll(() {
    registerFallbackValue(
      const JwtPayload(
        aud: 'aud',
        sub: 'sub',
        iss: 'iss',
        iat: 0,
        exp: 1,
        prm: 'prm',
      ),
    );
    registerFallbackValue(
      User(
        id: 'fallback',
        email: 'fallback@example.com',
        name: 'fallback',
        createdAt: DateTime.utc(2024, 1, 1),
      ),
    );
  });

  group('AuthService.login', () {
    late AuthService sut;
    late MockUserRepo mockUserRepo;
    late MockKeystoreRepo mockKeystoreRepo;
    late MockJwtService mockJwtService;
    late MockCryptoWorker mockCryptoWorker;

    final user = User(
      id: 'u-1',
      email: 'x@y.com',
      name: 'X',
      passwordHash: 'bcrypt-hash',
      createdAt: DateTime.utc(2026, 1, 1),
    );

    setUp(() {
      mockUserRepo = MockUserRepo();
      mockKeystoreRepo = MockKeystoreRepo();
      mockJwtService = MockJwtService();
      mockCryptoWorker = MockCryptoWorker();

      when(() => mockJwtService.accessTokenExpiry)
          .thenReturn(const Duration(hours: 1));
      when(() => mockJwtService.refreshTokenExpiry)
          .thenReturn(const Duration(days: 30));
      when(() => mockJwtService.encode(any())).thenReturn('jwt-token');

      sut = AuthService(
        userRepo: mockUserRepo,
        keystoreRepo: mockKeystoreRepo,
        jwt: mockJwtService,
        crypto: mockCryptoWorker,
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
      when(() => mockCryptoWorker.verifyPassword(any(), any()))
          .thenAnswer((_) async => false);

      await expectLater(
        sut.login(const LoginDto(email: 'x@y.com', password: 'wrong')),
        throwsA(isA<AuthFailureError>()),
      );
    });

    test('returns AuthResult on valid credentials', () async {
      when(() => mockUserRepo.findByEmail('x@y.com'))
          .thenAnswer((_) async => user);
      when(() => mockCryptoWorker.verifyPassword('pass123', user.passwordHash!))
          .thenAnswer((_) async => true);
      when(() => mockKeystoreRepo.create(user, any(), any())).thenAnswer(
        (inv) async => Keystore(
          id: 'k-1',
          client: user,
          primaryKey: inv.positionalArguments[1] as String,
          secondaryKey: inv.positionalArguments[2] as String,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );

      final result = await sut
          .login(const LoginDto(email: 'x@y.com', password: 'pass123'));

      expect(result.user.id, 'u-1');
      expect(result.tokens.accessToken, 'jwt-token');
      expect(result.tokens.refreshToken, 'jwt-token');
      verify(
        () => mockCryptoWorker.verifyPassword('pass123', user.passwordHash!),
      ).called(1);
      verify(() => mockKeystoreRepo.create(user, any(), any())).called(1);
      verify(() => mockJwtService.encode(any())).called(2);
    });
  });

  group('AuthService.signup', () {
    late AuthService sut;
    late MockUserRepo mockUserRepo;
    late MockKeystoreRepo mockKeystoreRepo;
    late MockJwtService mockJwtService;
    late MockCryptoWorker mockCryptoWorker;

    final newUser = User(
      id: 'u-2',
      email: 'new@y.com',
      name: 'New',
      passwordHash: 'hashed',
      createdAt: DateTime.utc(2026, 1, 1),
    );

    setUp(() {
      mockUserRepo = MockUserRepo();
      mockKeystoreRepo = MockKeystoreRepo();
      mockJwtService = MockJwtService();
      mockCryptoWorker = MockCryptoWorker();

      when(() => mockJwtService.accessTokenExpiry)
          .thenReturn(const Duration(hours: 1));
      when(() => mockJwtService.refreshTokenExpiry)
          .thenReturn(const Duration(days: 30));
      when(() => mockJwtService.encode(any())).thenReturn('jwt-token');
      when(() => mockCryptoWorker.hashPassword(any()))
          .thenAnswer((inv) async => 'hashed-${inv.positionalArguments.first}');

      sut = AuthService(
        userRepo: mockUserRepo,
        keystoreRepo: mockKeystoreRepo,
        jwt: mockJwtService,
        crypto: mockCryptoWorker,
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
      when(
        () => mockUserRepo.create(any(), any(), any(), any()),
      ).thenAnswer((inv) async {
        return (
          user: newUser,
          keystore: Keystore(
            id: 'k1',
            client: newUser,
            primaryKey: 'a',
            secondaryKey: 'b',
          )
        );
      });

      final result = await sut.signup(
        const SignupDto(name: 'X', email: 'new@y.com', password: 'p'),
      );

      expect(result.user.email, 'new@y.com');
      expect(result.tokens.accessToken, isNotEmpty);
      verify(() => mockCryptoWorker.hashPassword('p')).called(1);
      verify(() => mockUserRepo.create(any(), any(), any(), any())).called(1);
      verify(() => mockJwtService.encode(any())).called(2);
    });
  });

  group('AuthService.logout', () {
    late AuthService sut;
    late MockUserRepo mockUserRepo;
    late MockKeystoreRepo mockKeystoreRepo;
    late MockJwtService mockJwtService;
    late MockCryptoWorker mockCryptoWorker;

    final user = User(
      id: 'u-1',
      email: 'x@y.com',
      name: 'X',
      passwordHash: 'hash',
      createdAt: DateTime.utc(2026, 1, 1),
    );

    setUp(() {
      mockUserRepo = MockUserRepo();
      mockKeystoreRepo = MockKeystoreRepo();
      mockJwtService = MockJwtService();
      mockCryptoWorker = MockCryptoWorker();

      sut = AuthService(
        userRepo: mockUserRepo,
        keystoreRepo: mockKeystoreRepo,
        jwt: mockJwtService,
        crypto: mockCryptoWorker,
      );
    });

    test('removes keystore for valid access token', () async {
      when(() => mockJwtService.validate('access')).thenReturn(accessPayload);
      when(() => mockUserRepo.findById('u-1')).thenAnswer((_) async => user);
      when(() => mockKeystoreRepo.findForKey(user, 'access-key')).thenAnswer(
        (_) async => Keystore(
          id: 'k-1',
          client: user,
          primaryKey: 'access-key',
          secondaryKey: 'refresh',
        ),
      );
      when(() => mockKeystoreRepo.remove('k-1')).thenAnswer((_) async => null);

      await sut.logout('access');

      verify(() => mockKeystoreRepo.remove('k-1')).called(1);
    });
  });

  group('AuthService.refreshToken', () {
    late AuthService sut;
    late MockUserRepo mockUserRepo;
    late MockKeystoreRepo mockKeystoreRepo;
    late MockJwtService mockJwtService;
    late MockCryptoWorker mockCryptoWorker;

    final user = User(
      id: 'u-1',
      email: 'x@y.com',
      name: 'X',
      passwordHash: 'hash',
      createdAt: DateTime.utc(2026, 1, 1),
    );

    setUp(() {
      mockUserRepo = MockUserRepo();
      mockKeystoreRepo = MockKeystoreRepo();
      mockJwtService = MockJwtService();
      mockCryptoWorker = MockCryptoWorker();

      when(() => mockJwtService.accessTokenExpiry)
          .thenReturn(const Duration(hours: 1));
      when(() => mockJwtService.refreshTokenExpiry)
          .thenReturn(const Duration(days: 30));
      when(() => mockJwtService.encode(any())).thenReturn('new-jwt');

      sut = AuthService(
        userRepo: mockUserRepo,
        keystoreRepo: mockKeystoreRepo,
        jwt: mockJwtService,
        crypto: mockCryptoWorker,
      );
    });

    test('returns new tokens and rotates keys', () async {
      when(() => mockJwtService.decode('access')).thenReturn(accessPayload);
      when(() => mockJwtService.validate('refresh')).thenReturn(refreshPayload);
      when(() => mockUserRepo.findById('u-1')).thenAnswer((_) async => user);
      when(() => mockKeystoreRepo.find(user, 'access-key', 'refresh-key'))
          .thenAnswer(
        (_) async => Keystore(
          id: 'k-1',
          client: user,
          primaryKey: 'access-key',
          secondaryKey: 'refresh-key',
        ),
      );
      when(() => mockKeystoreRepo.remove('k-1')).thenAnswer((_) async => null);
      when(() => mockKeystoreRepo.create(user, any(), any())).thenAnswer(
        (inv) async => Keystore(
          id: 'k-2',
          client: user,
          primaryKey: inv.positionalArguments[1] as String,
          secondaryKey: inv.positionalArguments[2] as String,
        ),
      );

      final tokens = await sut.refreshToken(
        accessToken: 'access',
        refreshToken: 'refresh',
      );

      expect(tokens.accessToken, 'new-jwt');
      expect(tokens.refreshToken, 'new-jwt');
      verify(() => mockKeystoreRepo.remove('k-1')).called(1);
      verify(() => mockKeystoreRepo.create(user, any(), any())).called(1);
      verify(() => mockJwtService.encode(any())).called(2);
    });
  });
}
