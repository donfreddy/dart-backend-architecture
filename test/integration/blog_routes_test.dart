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

  setUp(() async {
    final signupRes = await app(
      _post('/v1/signup/basic', {
        'name': 'Blog Test Writer',
        'email': 'writer${DateTime.now().millisecondsSinceEpoch}$_emailSuffix',
        'password': _password,
      }),
    );
    final signupBody = _json(await signupRes.readAsString());
    accessToken = signupBody['data']['tokens']['accessToken'] as String?;
  });

  tearDown(() async {
    await pool.execute(
      Sql("DELETE FROM users WHERE email LIKE '%$_emailSuffix'"),
    );
  });

  group('POST /v1/blogs/writer', () {
    const endpoint = '/v1/blogs/writer';

    test('returns 401 without authorization header', () async {
      final res = await app(_post(endpoint, _validBlogPayload()));
      expect(res.statusCode, 401);
    });

    test('returns 201 with valid payload', () async {
      final res = await app(
        _authenticatedPost(endpoint, _validBlogPayload(), accessToken!),
      );
      expect(res.statusCode, 200);
      final body = _json(await res.readAsString());
      expect(body['status'], '10000');
      expect(body['data']['title'], 'Test Blog');
    });

    test('returns 400 when blog URL already exists', () async {
      await app(
        _authenticatedPost(endpoint, _validBlogPayload(), accessToken!),
      );

      final res = await app(
        _authenticatedPost(endpoint, _validBlogPayload(), accessToken!),
      );
      expect(res.statusCode, 400);
    });

    test('returns 400 when body is empty', () async {
      final res = await app(
        _authenticatedPost(endpoint, {}, accessToken!),
      );
      expect(res.statusCode, 400);
    });
  });

  group('GET /v1/blogs/url', () {
    const endpoint = '/v1/blogs/url';

    setUp(() async {
      final res = await app(
        _authenticatedPost(
          '/v1/blogs/writer',
          _validBlogPayload()..['blog_url'] = 'integration-test-url',
          accessToken!,
        ),
      );
      await res.readAsString();
    });

    test('returns blog for valid endpoint', () async {
      final res = await app(
        Request(
          'GET',
          Uri.parse('http://localhost$endpoint')
              .replace(queryParameters: {'endpoint': 'integration-test-url'}),
        ),
      );
      expect(res.statusCode, 200);
      final body = _json(await res.readAsString());
      expect(body['data']['blog_url'], 'integration-test-url');
    });

    test('returns 400 for non-existent endpoint', () async {
      final res = await app(
        Request(
          'GET',
          Uri.parse('http://localhost$endpoint')
              .replace(queryParameters: {'endpoint': 'does-not-exist'}),
        ),
      );
      expect(res.statusCode, 400);
    });
  });
}

Map<String, dynamic> _validBlogPayload() => {
      'title': 'Test Blog',
      'description': 'A test blog description',
      'text': 'This is the blog text content',
      'tags': ['dart', 'testing'],
      'blog_url': 'test-blog-${DateTime.now().millisecondsSinceEpoch}',
      'score': 0,
    };

Request _post(String path, Map<String, dynamic> body) => Request(
      'POST',
      Uri.parse('http://localhost$path'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(body),
    );

Request _authenticatedPost(
  String path,
  Map<String, dynamic> body,
  String accessToken,
) =>
    Request(
      'POST',
      Uri.parse('http://localhost$path'),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );

Map<String, dynamic> _json(String body) =>
    jsonDecode(body) as Map<String, dynamic>;
