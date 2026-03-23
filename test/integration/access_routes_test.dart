// ignore_for_file: avoid_dynamic_calls

import 'dart:convert';

import 'package:dart_backend_architecture/app.dart';
import 'package:dart_backend_architecture/config.dart';
import 'package:dart_backend_architecture/di/composition_root.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

// All integration test users share this email suffix: used for targeted cleanup.
const _emailSuffix = '@test.dba';
const _password = 'secret123';

void main() {
  late CompositionRoot root;
  late Handler app;
  late Pool<dynamic> pool;

  setUpAll(() async {
    final config = AppConfig.fromEnv();
    pool = Pool.withUrl(config.databaseUrl);
    root = await CompositionRoot.initialize(config);
    // Full middleware stack (error handler, tracing, body limit, security headers)
    app = buildApp(root.router);
  });

  tearDownAll(() async {
    await pool.execute(
      Sql("DELETE FROM users WHERE email LIKE '%$_emailSuffix'"),
    );
    await pool.close();
    await root.dispose();
  });

  // ── Signup ─────────────────────────────────────────────────────────────────

  group('POST /v1/signup/basic', () {
    const endpoint = '/v1/signup/basic';

    tearDown(() async {
      await pool.execute(
        Sql("DELETE FROM users WHERE email LIKE '%$_emailSuffix'"),
      );
    });

    test('returns 400 when body is empty', () async {
      final res = await app(_post(endpoint, {}));
      expect(res.statusCode, 400);
      final body = _json(await res.readAsString());
      expect(body['status'], '10001');
    });

    test('returns 400 when name is missing', () async {
      final res = await app(_post(endpoint, {
        'email': 'x$_emailSuffix',
        'password': _password,
      },),);
      expect(res.statusCode, 400);
      final body = _json(await res.readAsString());
      expect(body['data']['errors'].toString(), contains('name'));
    });

    test('returns 400 when email is missing', () async {
      final res = await app(_post(endpoint, {
        'name': 'Test User',
        'password': _password,
      },),);
      expect(res.statusCode, 400);
      final body = _json(await res.readAsString());
      expect(body['data']['errors'].toString(), contains('email'));
    });

    test('returns 400 when password is missing', () async {
      final res = await app(_post(endpoint, {
        'name': 'Test User',
        'email': 'x$_emailSuffix',
      },),);
      expect(res.statusCode, 400);
      final body = _json(await res.readAsString());
      expect(body['data']['errors'].toString(), contains('password'));
    });

    test('returns 400 when email format is invalid', () async {
      final res = await app(_post(endpoint, {
        'name': 'Test User',
        'email': 'not-an-email',
        'password': _password,
      },),);
      expect(res.statusCode, 400);
    });

    test('returns 400 when name is shorter than 3 chars', () async {
      final res = await app(_post(endpoint, {
        'name': 'AB',
        'email': 'x$_emailSuffix',
        'password': _password,
      },),);
      expect(res.statusCode, 400);
    });

    test('returns 400 when password is shorter than 6 chars', () async {
      final res = await app(_post(endpoint, {
        'name': 'Test User',
        'email': 'x$_emailSuffix',
        'password': 'abc',
      },),);
      expect(res.statusCode, 400);
    });

    test('returns 200 with user and tokens on valid signup', () async {
      final res = await app(_post(endpoint, {
        'name': 'Test User',
        'email': 'signup$_emailSuffix',
        'password': _password,
      },),);

      expect(res.statusCode, 200);
      final body = _json(await res.readAsString());
      expect(body['status'], '10000');

      final user = body['data']['user'] as Map<String, dynamic>;
      expect(user['id'], isA<String>());
      expect(user['email'], 'signup$_emailSuffix');
      expect(user['name'], 'Test User');
      expect(user['roles'], contains('learner'));
      expect(user.containsKey('passwordHash'), isFalse);

      final tokens = body['data']['tokens'] as Map<String, dynamic>;
      expect(tokens['accessToken'], isA<String>());
      expect(tokens['refreshToken'], isA<String>());
    });

    test('returns 400 when user is already registered', () async {
      final payload = {
        'name': 'Test User',
        'email': 'duplicate$_emailSuffix',
        'password': _password,
      };
      // First signup
      final first = await app(_post(endpoint, payload));
      expect(first.statusCode, 200);
      await first.readAsString(); // drain

      // Second signup with same email
      final second = await app(_post(endpoint, payload));
      expect(second.statusCode, 400);
      final body = _json(await second.readAsString());
      expect(body['message'].toString().toLowerCase(), contains('registered'));
    });
  });

  // ── Login ──────────────────────────────────────────────────────────────────

  group('POST /v1/login/basic', () {
    const endpoint = '/v1/login/basic';
    const loginEmail = 'login$_emailSuffix';

    setUpAll(() async {
      // Create the user we will login with
      final res = await app(_post('/v1/signup/basic', {
        'name': 'Login Test User',
        'email': loginEmail,
        'password': _password,
      },),);
      await res.readAsString(); // drain response
      expect(res.statusCode, 200, reason: 'setUpAll: signup must succeed');
    });

    tearDownAll(() async {
      await pool.execute(
        Sql.named('DELETE FROM users WHERE email = @email'),
        parameters: {'email': loginEmail},
      );
    });

    test('returns 400 when body is empty', () async {
      final res = await app(_post(endpoint, {}));
      expect(res.statusCode, 400);
    });

    test('returns 400 when email is missing', () async {
      final res = await app(_post(endpoint, {'password': _password}));
      expect(res.statusCode, 400);
      final body = _json(await res.readAsString());
      expect(body['data']['errors'].toString(), contains('email'));
    });

    test('returns 400 when password is missing', () async {
      final res = await app(_post(endpoint, {'email': loginEmail}));
      expect(res.statusCode, 400);
      final body = _json(await res.readAsString());
      expect(body['data']['errors'].toString(), contains('password'));
    });

    test('returns 400 when email format is invalid', () async {
      final res = await app(_post(endpoint, {
        'email': 'not-valid',
        'password': _password,
      },),);
      expect(res.statusCode, 400);
    });

    test('returns 400 when password is shorter than 6 chars', () async {
      final res = await app(_post(endpoint, {
        'email': loginEmail,
        'password': 'abc',
      },),);
      expect(res.statusCode, 400);
    });

    test('returns 400 when user is not registered', () async {
      final res = await app(_post(endpoint, {
        'email': 'notregistered$_emailSuffix',
        'password': _password,
      },),);
      expect(res.statusCode, 400);
      final body = _json(await res.readAsString());
      expect(body['message'].toString().toLowerCase(), contains('not registered'));
    });

    test('returns 401 for wrong password', () async {
      final res = await app(_post(endpoint, {
        'email': loginEmail,
        'password': 'wrongpassword',
      },),);
      expect(res.statusCode, 401);
      final body = _json(await res.readAsString());
      expect(body['message'].toString().toLowerCase(), contains('authentication'));
    });

    test('returns 200 with user and tokens for correct credentials', () async {
      final res = await app(_post(endpoint, {
        'email': loginEmail,
        'password': _password,
      },),);

      expect(res.statusCode, 200);
      final body = _json(await res.readAsString());
      expect(body['status'], '10000');

      final user = body['data']['user'] as Map<String, dynamic>;
      expect(user['email'], loginEmail);
      expect(user['name'], 'Login Test User');
      expect(user.containsKey('passwordHash'), isFalse);

      final tokens = body['data']['tokens'] as Map<String, dynamic>;
      expect(tokens['accessToken'], isA<String>());
      expect(tokens['refreshToken'], isA<String>());

      // Tokens must be distinct (access ≠ refresh)
      expect(tokens['accessToken'], isNot(equals(tokens['refreshToken'])));
    });

    test('returns 200 on repeated logins (new keystore each time)', () async {
      final res1 = await app(_post(endpoint, {
        'email': loginEmail,
        'password': _password,
      },),);
      final res2 = await app(_post(endpoint, {
        'email': loginEmail,
        'password': _password,
      },),);

      expect(res1.statusCode, 200);
      expect(res2.statusCode, 200);

      final tokens1 = _json(await res1.readAsString())['data']['tokens'];
      final tokens2 = _json(await res2.readAsString())['data']['tokens'];

      // Each login issues fresh tokens
      expect(tokens1['accessToken'], isNot(equals(tokens2['accessToken'])));
    });
  });
}

// ── Helpers ────────────────────────────────────────────────────────────────

Request _post(String path, Map<String, dynamic> body) => Request(
      'POST',
      Uri.parse('http://localhost$path'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(body),
    );

Map<String, dynamic> _json(String body) =>
    jsonDecode(body) as Map<String, dynamic>;
