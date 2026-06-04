// ignore_for_file: avoid_dynamic_calls

import 'dart:convert';

import 'package:dart_backend_architecture/app.dart';
import 'package:dart_backend_architecture/config.dart';
import 'package:dart_backend_architecture/di/composition_root.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

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
    app = buildApp(root.router);
  });

  tearDownAll(() async {
    await pool.execute(
      Sql("DELETE FROM users WHERE email LIKE '%$_emailSuffix'"),
    );
    await pool.close();
    await root.dispose();
  });

  String? accessToken;
  String? userId;

  setUp(() async {
    final signupRes = await app(
      _post('/v1/signup/basic', {
        'name': 'Profile Test User',
        'email': 'profile${DateTime.now().millisecondsSinceEpoch}$_emailSuffix',
        'password': _password,
      }),
    );
    final signupBody = _json(await signupRes.readAsString());
    accessToken = signupBody['data']['tokens']['accessToken'] as String?;
    userId = signupBody['data']['user']['id'] as String?;
  });

  tearDown(() async {
    await pool.execute(
      Sql("DELETE FROM users WHERE email LIKE '%$_emailSuffix'"),
    );
  });

  group('GET /v1/profile/public/id/<id>', () {
    test('returns public profile for valid user', () async {
      final res = await app(
        Request(
          'GET',
          Uri.parse('http://localhost/v1/profile/public/id/$userId'),
        ),
      );
      expect(res.statusCode, 200);
      final body = _json(await res.readAsString());
      expect(body['data']['name'], 'Profile Test User');
    });

    test('returns 400 for non-existent user', () async {
      final res = await app(
        Request(
          'GET',
          Uri.parse('http://localhost/v1/profile/public/id/non-existent'),
        ),
      );
      expect(res.statusCode, 400);
    });
  });

  group('GET /v1/profile/my', () {
    test('returns my profile with valid token', () async {
      final res = await app(
        _authenticatedGet('/v1/profile/my', accessToken!),
      );
      expect(res.statusCode, 200);
      final body = _json(await res.readAsString());
      expect(body['data']['name'], 'Profile Test User');
      expect(body['data']['roles'], isA<List<dynamic>>());
    });

    test('returns 401 without token', () async {
      final res = await app(
        Request('GET', Uri.parse('http://localhost/v1/profile/my')),
      );
      expect(res.statusCode, 401);
    });
  });

  group('PUT /v1/profile', () {
    test('updates profile name with valid token', () async {
      final res = await app(
        _authenticatedPut(
          '/v1/profile',
          {'name': 'Updated Name'},
          accessToken!,
        ),
      );
      expect(res.statusCode, 200);
      final body = _json(await res.readAsString());
      expect(body['data']['name'], 'Updated Name');
    });

    test('returns 401 without token', () async {
      final res = await app(
        _put('/v1/profile', {'name': 'Updated Name'}),
      );
      expect(res.statusCode, 401);
    });

    test('returns 400 with empty body', () async {
      final res = await app(
        _authenticatedPut('/v1/profile', {}, accessToken!),
      );
      expect(res.statusCode, 400);
    });
  });
}

Request _post(String path, Map<String, dynamic> body) => Request(
      'POST',
      Uri.parse('http://localhost$path'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(body),
    );

Request _put(String path, Map<String, dynamic> body) => Request(
      'PUT',
      Uri.parse('http://localhost$path'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(body),
    );

Request _authenticatedGet(String path, String accessToken) => Request(
      'GET',
      Uri.parse('http://localhost$path'),
      headers: {'authorization': 'Bearer $accessToken'},
    );

Request _authenticatedPut(
  String path,
  Map<String, dynamic> body,
  String accessToken,
) =>
    Request(
      'PUT',
      Uri.parse('http://localhost$path'),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );

Map<String, dynamic> _json(String body) =>
    jsonDecode(body) as Map<String, dynamic>;
