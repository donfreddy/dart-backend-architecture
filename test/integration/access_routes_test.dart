// ignore_for_file: avoid_dynamic_calls

import 'dart:convert';

import 'package:dart_backend_architecture/app.dart';
import 'package:dart_backend_architecture/routes/router.dart';
import 'package:dart_backend_architecture/services/auth_service.dart';
import 'package:dart_backend_architecture/core/jwt/jwt_service.dart';
import 'package:dart_backend_architecture/database/model/user.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../mocks/mocks.dart';

void main() {
  late MockAuthService authService;
  late Handler app;

  setUpAll(() {
    registerFallbackValue(
      const SignupDto(
        name: 'x',
        email: 'a@b.com',
        password: 'pass',
      ),
    );
    registerFallbackValue(
      const LoginDto(
        email: 'a@b.com',
        password: 'pass',
      ),
    );
  });

  setUp(() {
    authService = MockAuthService();
    app = buildApp(
      _buildRouter(authService),
      corsAllowedOrigins: const [],
    );
  });

  test('POST /v1/signup/basic returns 200 on success', () async {
    final result = AuthResult(
      user: _sampleUser,
      tokens: const TokenPair(accessToken: 'a', refreshToken: 'r'),
    );
    when(() => authService.signup(any())).thenAnswer((_) async => result);

    final res = await app(
      Request(
        'POST',
        Uri.parse('http://localhost/v1/signup/basic'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'name': 'John',
          'email': 'john@example.com',
          'password': 'secret123',
        }),
      ),
    );

    expect(res.statusCode, 200);
    final payload = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
    expect(payload['status'], '10000');
    expect(payload['data']['user']['email'], 'user@example.com');
    verify(() => authService.signup(any())).called(1);
  });

  test('POST /v1/signup/basic returns 400 on invalid body', () async {
    final res = await app(
      Request(
        'POST',
        Uri.parse('http://localhost/v1/signup/basic'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'email': 'john@example.com'}), // missing name/password
      ),
    );

    expect(res.statusCode, 400);
    verifyNever(() => authService.signup(any()));
  });

  test('POST /v1/login/basic returns 200 on success', () async {
    final result = AuthResult(
      user: _sampleUser,
      tokens: const TokenPair(accessToken: 'a', refreshToken: 'r'),
    );
    when(() => authService.login(any())).thenAnswer((_) async => result);

    final res = await app(
      Request(
        'POST',
        Uri.parse('http://localhost/v1/login/basic'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'email': 'john@example.com', 'password': 'secret123'}),
      ),
    );

    expect(res.statusCode, 200);
    final payload = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
    expect(payload['data']['tokens']['accessToken'], 'a');
    verify(() => authService.login(any())).called(1);
  });

  test('POST /v1/login/basic returns 400 on bad payload', () async {
    final res = await app(
      Request(
        'POST',
        Uri.parse('http://localhost/v1/login/basic'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'email': 'john@example.com'}), // missing password
      ),
    );

    expect(res.statusCode, 400);
    verifyNever(() => authService.login(any()));
  });
}

Handler _buildRouter(AuthService authService) {
  return buildRouter(
    authService: authService,
    blogService: MockBlogService(),
    jwtService: MockJwtService(),
    userRepo: MockUserRepo(),
    keystoreRepo: MockKeystoreRepo(),
    roleRepo: MockRoleRepo(),
    dbCheck: () async => true,
    cacheCheck: () async => true,
    natsCheck: () async => true,
  );
}

final _sampleUser = User(
  id: 'u-1',
  email: 'user@example.com',
  name: 'User',
  roles: const ['learner'],
  createdAt: DateTime.utc(2026, 1, 1),
);
