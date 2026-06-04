import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/core/jwt/jwt_service.dart';
import 'package:dart_backend_architecture/database/model/keystore.dart';
import 'package:dart_backend_architecture/database/model/user.dart';
import 'package:dart_backend_architecture/services/token_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../mocks/mocks.dart';

void main() {
  final user = User(
    id: 'u-1',
    email: 'x@y.com',
    name: 'X',
    createdAt: DateTime.utc(2026, 1, 1),
  );

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
    exp: 999,
    prm: 'refresh-key',
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
    registerFallbackValue(
      const JwtPayload(
        aud: 'aud',
        sub: 'fallback',
        iss: 'iss',
        iat: 0,
        exp: 1,
        prm: 'key',
      ),
    );
  });

  group('TokenService.issue', () {
    late MockKeystoreRepo keystoreRepo;
    late MockJwtService jwt;
    late TokenService sut;

    setUp(() {
      keystoreRepo = MockKeystoreRepo();
      jwt = MockJwtService();
      when(() => jwt.accessTokenExpiry).thenReturn(const Duration(hours: 1));
      when(() => jwt.refreshTokenExpiry).thenReturn(const Duration(days: 30));
      when(() => jwt.encode(any())).thenReturn('encoded-jwt');
      sut = TokenService(keystoreRepo: keystoreRepo, jwt: jwt);
    });

    test('creates keystore and returns token pair', () async {
      when(() => keystoreRepo.create(any(), any(), any()))
          .thenAnswer((_) async => Keystore(
                id: 'k-1',
                client: user,
                primaryKey: 'pk',
                secondaryKey: 'sk',
              ));

      final result = await sut.issue(user);

      expect(result.accessToken, 'encoded-jwt');
      verify(() => keystoreRepo.create(any(), any(), any())).called(1);
    });
  });

  group('TokenService.buildForExistingKeys', () {
    late MockJwtService jwt;
    late TokenService sut;

    setUp(() {
      jwt = MockJwtService();
      when(() => jwt.accessTokenExpiry).thenReturn(const Duration(hours: 1));
      when(() => jwt.refreshTokenExpiry).thenReturn(const Duration(days: 30));
      when(() => jwt.encode(any())).thenReturn('encoded-jwt');
      sut = TokenService(keystoreRepo: MockKeystoreRepo(), jwt: jwt);
    });

    test('returns token pair without touching keystore', () async {
      final result = sut.buildForExistingKeys('u-1', 'ak', 'rk');

      expect(result.accessToken, 'encoded-jwt');
      expect(result.refreshToken, 'encoded-jwt');
    });
  });

  group('TokenService.revoke', () {
    late MockKeystoreRepo keystoreRepo;
    late MockJwtService jwt;
    late TokenService sut;

    setUp(() {
      keystoreRepo = MockKeystoreRepo();
      jwt = MockJwtService();
      sut = TokenService(keystoreRepo: keystoreRepo, jwt: jwt);
    });

    test('removes keystore when found', () async {
      when(() => keystoreRepo.findForKey(user, 'pk')).thenAnswer(
        (_) async => Keystore(
          id: 'k-1',
          client: user,
          primaryKey: 'pk',
          secondaryKey: 'sk',
        ),
      );
      when(() => keystoreRepo.remove('k-1')).thenAnswer((_) async => null);

      await sut.revoke(user: user, primaryKey: 'pk');

      verify(() => keystoreRepo.remove('k-1')).called(1);
    });

    test('throws AuthFailureError when keystore not found', () async {
      when(() => keystoreRepo.findForKey(user, 'pk'))
          .thenAnswer((_) async => null);

      await expectLater(
        sut.revoke(user: user, primaryKey: 'pk'),
        throwsA(isA<AuthFailureError>()),
      );
    });
  });

  group('TokenService.rotate', () {
    late MockKeystoreRepo keystoreRepo;
    late MockJwtService jwt;
    late TokenService sut;

    setUp(() {
      keystoreRepo = MockKeystoreRepo();
      jwt = MockJwtService();
      when(() => jwt.accessTokenExpiry).thenReturn(const Duration(hours: 1));
      when(() => jwt.refreshTokenExpiry).thenReturn(const Duration(days: 30));
      when(() => jwt.encode(any())).thenReturn('encoded-jwt');
      sut = TokenService(keystoreRepo: keystoreRepo, jwt: jwt);
    });

    test('rotates tokens and issues new pair', () async {
      when(() => jwt.decode('access')).thenAnswer((_) async => accessPayload);
      when(() => jwt.validate('refresh'))
          .thenAnswer((_) async => refreshPayload);
      when(() => keystoreRepo.find(user, 'access-key', 'refresh-key'))
          .thenAnswer(
        (_) async => Keystore(
          id: 'k-1',
          client: user,
          primaryKey: 'access-key',
          secondaryKey: 'refresh-key',
        ),
      );
      when(() => keystoreRepo.remove('k-1')).thenAnswer((_) async => null);
      when(() => keystoreRepo.create(any(), any(), any()))
          .thenAnswer((_) async => Keystore(
                id: 'k-2',
                client: user,
                primaryKey: 'pk',
                secondaryKey: 'sk',
              ));

      final result = await sut.rotate(
        user: user,
        accessToken: 'access',
        refreshToken: 'refresh',
      );

      expect(result.accessToken, 'encoded-jwt');
      verify(() => keystoreRepo.remove('k-1')).called(1);
      verify(() => keystoreRepo.create(any(), any(), any())).called(1);
    });

    test('throws AuthFailureError when subject mismatch', () async {
      const otherUserPayload = JwtPayload(
        aud: 'aud',
        sub: 'u-2',
        iss: 'iss',
        iat: 0,
        exp: 999,
        prm: 'refresh-key',
      );
      when(() => jwt.decode('access')).thenAnswer((_) async => accessPayload);
      when(() => jwt.validate('refresh'))
          .thenAnswer((_) async => otherUserPayload);

      await expectLater(
        sut.rotate(user: user, accessToken: 'access', refreshToken: 'refresh'),
        throwsA(isA<AuthFailureError>()),
      );
    });

    test('throws AuthFailureError when keystore not found', () async {
      when(() => jwt.decode('access')).thenAnswer((_) async => accessPayload);
      when(() => jwt.validate('refresh'))
          .thenAnswer((_) async => refreshPayload);
      when(() => keystoreRepo.find(user, 'access-key', 'refresh-key'))
          .thenAnswer((_) async => null);

      await expectLater(
        sut.rotate(user: user, accessToken: 'access', refreshToken: 'refresh'),
        throwsA(isA<AuthFailureError>()),
      );
    });
  });
}
