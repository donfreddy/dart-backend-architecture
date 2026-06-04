import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/core/jwt/jwt_service.dart';
import 'package:dart_backend_architecture/core/middleware/auth_middleware.dart';
import 'package:dart_backend_architecture/database/model/keystore.dart';
import 'package:dart_backend_architecture/database/model/user.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../../mocks/mocks.dart';

void main() {
  const payload = JwtPayload(
    aud: 'dba-users',
    sub: 'u-1',
    iss: 'dart_backend_architecture',
    iat: 0,
    exp: 9999999999,
    prm: 'key-1',
  );

  final user = User(
    id: 'u-1',
    email: 'x@y.com',
    name: 'X',
    createdAt: DateTime.utc(2026, 1, 1),
    roles: const ['learner'],
  );

  final keystore = Keystore(
    id: 'k-1',
    client: user,
    primaryKey: 'key-1',
    secondaryKey: 'key-2',
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

  group('authMiddleware', () {
    late MockJwtService jwtService;
    late MockUserRepo userRepo;
    late MockKeystoreRepo keystoreRepo;

    setUp(() {
      jwtService = MockJwtService();
      userRepo = MockUserRepo();
      keystoreRepo = MockKeystoreRepo();
    });

    Future<Response> okHandler(Request request) async {
      // Verify context is properly enriched
      expect(request.authUser.id, 'u-1');
      expect(request.authKeystore.primaryKey, 'key-1');
      expect(request.accessToken, 'bearer-token');
      return Response.ok('ok');
    }

    test('allows request with valid bearer token', () async {
      when(() => jwtService.validate('bearer-token'))
          .thenAnswer((_) async => payload);
      when(() => userRepo.findById('u-1')).thenAnswer((_) async => user);
      when(() => keystoreRepo.findForKey(user, 'key-1'))
          .thenAnswer((_) async => keystore);

      final mw = authMiddleware(
        jwtService: jwtService,
        userRepo: userRepo,
        keystoreRepo: keystoreRepo,
      );
      final handler = mw(okHandler);
      final req = Request(
        'GET',
        Uri.parse('http://localhost/'),
        headers: {'authorization': 'Bearer bearer-token'},
      );

      final res = await handler(req);

      expect(res.statusCode, 200);
    });

    test('blocks request with missing authorization header', () async {
      final mw = authMiddleware(
        jwtService: jwtService,
        userRepo: userRepo,
        keystoreRepo: keystoreRepo,
      );
      final handler = mw(okHandler);
      final req = Request('GET', Uri.parse('http://localhost/'));

      await expectLater(
        handler(req),
        throwsA(isA<AuthFailureError>()),
      );
    });

    test('blocks request with invalid bearer format', () async {
      final mw = authMiddleware(
        jwtService: jwtService,
        userRepo: userRepo,
        keystoreRepo: keystoreRepo,
      );
      final handler = mw(okHandler);
      final req = Request(
        'GET',
        Uri.parse('http://localhost/'),
        headers: {'authorization': 'Invalid bearer-token'},
      );

      await expectLater(
        handler(req),
        throwsA(isA<BadRequestError>()),
      );
    });

    test('wraps TokenExpiredError as AccessTokenError', () async {
      when(() => jwtService.validate('expired-token'))
          .thenThrow(const TokenExpiredError());

      final mw = authMiddleware(
        jwtService: jwtService,
        userRepo: userRepo,
        keystoreRepo: keystoreRepo,
      );
      final handler = mw(okHandler);
      final req = Request(
        'GET',
        Uri.parse('http://localhost/'),
        headers: {'authorization': 'Bearer expired-token'},
      );

      await expectLater(
        handler(req),
        throwsA(isA<AccessTokenError>()),
      );
    });

    test('blocks request when user not found', () async {
      when(() => jwtService.validate('bearer-token'))
          .thenAnswer((_) async => payload);
      when(() => userRepo.findById('u-1')).thenAnswer((_) async => null);

      final mw = authMiddleware(
        jwtService: jwtService,
        userRepo: userRepo,
        keystoreRepo: keystoreRepo,
      );
      final handler = mw(okHandler);
      final req = Request(
        'GET',
        Uri.parse('http://localhost/'),
        headers: {'authorization': 'Bearer bearer-token'},
      );

      await expectLater(
        handler(req),
        throwsA(isA<AuthFailureError>()),
      );
    });

    test('blocks request when keystore not found', () async {
      when(() => jwtService.validate('bearer-token'))
          .thenAnswer((_) async => payload);
      when(() => userRepo.findById('u-1')).thenAnswer((_) async => user);
      when(() => keystoreRepo.findForKey(user, 'key-1'))
          .thenAnswer((_) async => null);

      final mw = authMiddleware(
        jwtService: jwtService,
        userRepo: userRepo,
        keystoreRepo: keystoreRepo,
      );
      final handler = mw(okHandler);
      final req = Request(
        'GET',
        Uri.parse('http://localhost/'),
        headers: {'authorization': 'Bearer bearer-token'},
      );

      await expectLater(
        handler(req),
        throwsA(isA<AuthFailureError>()),
      );
    });
  });
}
