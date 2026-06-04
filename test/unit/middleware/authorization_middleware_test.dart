import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/core/middleware/authorization_middleware.dart';
import 'package:dart_backend_architecture/core/request_context_keys.dart';
import 'package:dart_backend_architecture/database/model/role.dart';
import 'package:dart_backend_architecture/database/model/user.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../../mocks/mocks.dart';

void main() {
  final userWithRole = User(
    id: 'u-1',
    email: 'writer@example.com',
    name: 'Writer',
    createdAt: DateTime.utc(2026, 1, 1),
    roles: const ['WRITER'],
  );

  final userWithoutRole = User(
    id: 'u-2',
    email: 'learner@example.com',
    name: 'Learner',
    createdAt: DateTime.utc(2026, 1, 1),
    roles: const ['LEARNER'],
  );

  final userEmptyRoles = User(
    id: 'u-3',
    email: 'empty@example.com',
    name: 'Empty',
    createdAt: DateTime.utc(2026, 1, 1),
    roles: const [],
  );

  const writerRole = Role(id: 'r-1', code: 'WRITER');

  Request authenticatedRequest(User user) => Request(
        'GET',
        Uri.parse('http://localhost/'),
        context: {RequestContextKeys.authUser: user},
      );

  group('authorizationMiddleware', () {
    late MockRoleRepo roleRepo;

    setUp(() {
      roleRepo = MockRoleRepo();
    });

    Future<Response> okHandler(Request request) async {
      expect(request.currentRoleCode, 'WRITER');
      return Response.ok('ok');
    }

    test('allows request when user has the required role', () async {
      when(() => roleRepo.findByCode('WRITER'))
          .thenAnswer((_) async => writerRole);

      final mw = authorizationMiddleware(
        roleRepo: roleRepo,
        roleCode: 'WRITER',
      );
      final handler = mw(okHandler);
      final req = authenticatedRequest(userWithRole);

      final res = await handler(req);
      expect(res.statusCode, 200);
    });

    test('blocks request when roleCode is empty', () async {
      final mw = authorizationMiddleware(
        roleRepo: roleRepo,
        roleCode: '',
      );
      final handler = mw(okHandler);
      final req = authenticatedRequest(userWithRole);

      await expectLater(
        handler(req),
        throwsA(isA<AuthFailureError>()),
      );
    });

    test('blocks request when user has no roles', () async {
      final mw = authorizationMiddleware(
        roleRepo: roleRepo,
        roleCode: 'WRITER',
      );
      final handler = mw(okHandler);
      final req = authenticatedRequest(userEmptyRoles);

      await expectLater(
        handler(req),
        throwsA(isA<AuthFailureError>()),
      );
    });

    test('blocks request when role not found in database', () async {
      when(() => roleRepo.findByCode('WRITER')).thenAnswer((_) async => null);

      final mw = authorizationMiddleware(
        roleRepo: roleRepo,
        roleCode: 'WRITER',
      );
      final handler = mw(okHandler);
      final req = authenticatedRequest(userWithRole);

      await expectLater(
        handler(req),
        throwsA(isA<AuthFailureError>()),
      );
    });

    test('blocks request when user lacks the required role', () async {
      when(() => roleRepo.findByCode('WRITER'))
          .thenAnswer((_) async => writerRole);

      final mw = authorizationMiddleware(
        roleRepo: roleRepo,
        roleCode: 'WRITER',
      );
      final handler = mw(okHandler);
      final req = authenticatedRequest(userWithoutRole);

      await expectLater(
        handler(req),
        throwsA(isA<AuthFailureError>()),
      );
    });

    test('blocks request when no authenticated user in context', () async {
      final mw = authorizationMiddleware(
        roleRepo: roleRepo,
        roleCode: 'WRITER',
      );
      final handler = mw(okHandler);
      final req = Request('GET', Uri.parse('http://localhost/'));

      await expectLater(
        handler(req),
        throwsA(isA<AuthFailureError>()),
      );
    });

    test('enriches request context with currentRoleCode', () async {
      when(() => roleRepo.findByCode('WRITER'))
          .thenAnswer((_) async => writerRole);

      String? capturedRoleCode;

      Future<Response> capturingHandler(Request request) async {
        capturedRoleCode = request.currentRoleCode;
        return Response.ok('ok');
      }

      final mw = authorizationMiddleware(
        roleRepo: roleRepo,
        roleCode: 'WRITER',
      );
      final handler = mw(capturingHandler);
      final req = authenticatedRequest(userWithRole);

      await handler(req);
      expect(capturedRoleCode, 'WRITER');
    });
  });
}
