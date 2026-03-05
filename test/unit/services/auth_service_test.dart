import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/core/jwt/jwt_service.dart';
import 'package:dart_backend_architecture/database/model/keystore.dart';
import 'package:dart_backend_architecture/database/model/user.dart';
import 'package:dart_backend_architecture/services/auth_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import '../../mocks/mocks.dart';

void main() {
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
  });

  group('AuthService.login', () {
    late AuthService sut;
    late MockUserRepo mockUserRepo;
    late MockKeystoreRepo mockKeystoreRepo;
    late MockJwtService mockJwtService;

    final user = User(
      id: 'u-1',
      email: 'x@y.com',
      name: 'X',
      passwordHash: sha256.convert(utf8.encode('pass123')).toString(),
      createdAt: DateTime.utc(2026, 1, 1),
    );

    setUp(() {
      mockUserRepo = MockUserRepo();
      mockKeystoreRepo = MockKeystoreRepo();
      mockJwtService = MockJwtService();

      when(() => mockJwtService.accessTokenExpiry).thenReturn(const Duration(hours: 1));
      when(() => mockJwtService.refreshTokenExpiry).thenReturn(const Duration(days: 30));
      when(() => mockJwtService.encode(any())).thenReturn('jwt-token');

      sut = AuthService(
        userRepo: mockUserRepo,
        keystoreRepo: mockKeystoreRepo,
        jwt: mockJwtService,
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

      await expectLater(
        sut.login(const LoginDto(email: 'x@y.com', password: 'wrong')),
        throwsA(isA<AuthFailureError>()),
      );
    });

    test('returns AuthResult on valid credentials', () async {
      when(() => mockUserRepo.findByEmail('x@y.com')).thenAnswer((_) async => user);
      when(() => mockKeystoreRepo.create(user, any(), any())).thenAnswer(
        (inv) async => Keystore(
          id: 'k-1',
          client: user,
          primaryKey: inv.positionalArguments[1] as String,
          secondaryKey: inv.positionalArguments[2] as String,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );

      final result = await sut.login(const LoginDto(email: 'x@y.com', password: 'pass123'));

      expect(result.user.id, 'u-1');
      expect(result.tokens.accessToken, 'jwt-token');
      expect(result.tokens.refreshToken, 'jwt-token');
      verify(() => mockKeystoreRepo.create(user, any(), any())).called(1);
      verify(() => mockJwtService.encode(any())).called(2);
    });
  });
}
