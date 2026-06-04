import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/core/middleware/api_key_middleware.dart';
import 'package:dart_backend_architecture/database/model/api_key.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/api_key_repo.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

class MockApiKeyRepo extends Mock implements ApiKeyRepo {}

void main() {
  group('apiKeyMiddleware', () {
    late MockApiKeyRepo apiKeyRepo;

    setUp(() {
      apiKeyRepo = MockApiKeyRepo();
    });

    Future<Response> okHandler(Request _) async => Response.ok('ok');

    test('allows request with valid api key', () async {
      when(() => apiKeyRepo.findByKey('valid-key')).thenAnswer(
        (_) async => const ApiKey(
          key: 'valid-key',
          version: 1,
          metadata: 'test',
        ),
      );

      final mw = apiKeyMiddleware(apiKeyRepo);
      final handler = mw(okHandler);
      final req = Request(
        'GET',
        Uri.parse('http://localhost/'),
        headers: {'x-api-key': 'valid-key'},
      );

      final res = await handler(req);

      expect(res.statusCode, 200);
    });

    test('blocks request with missing api key header', () async {
      final mw = apiKeyMiddleware(apiKeyRepo);
      final handler = mw(okHandler);
      final req = Request('GET', Uri.parse('http://localhost/'));

      await expectLater(
        handler(req),
        throwsA(isA<ForbiddenError>()),
      );
    });

    test('blocks request with invalid api key', () async {
      when(() => apiKeyRepo.findByKey('invalid-key'))
          .thenAnswer((_) async => null);

      final mw = apiKeyMiddleware(apiKeyRepo);
      final handler = mw(okHandler);
      final req = Request(
        'GET',
        Uri.parse('http://localhost/'),
        headers: {'x-api-key': 'invalid-key'},
      );

      await expectLater(
        handler(req),
        throwsA(isA<ForbiddenError>()),
      );
    });

    test('skips validation for OPTIONS preflight requests', () async {
      final mw = apiKeyMiddleware(apiKeyRepo);
      final handler = mw(okHandler);
      final req = Request('OPTIONS', Uri.parse('http://localhost/'));

      final res = await handler(req);

      expect(res.statusCode, 200);
    });
  });
}
