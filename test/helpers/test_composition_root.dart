import 'package:dart_backend_architecture/routes/router.dart';
import 'package:dart_backend_architecture/services/auth_service.dart';
import 'package:shelf/shelf.dart';

import '../mocks/mocks.dart';

final class TestCompositionRoot {
  final MockUserRepo userRepo;
  final MockBlogRepo blogRepo;
  final MockJwtService jwtService;
  final MockPasswordHasher cryptoHasher;
  final MockKeystoreRepo keystoreRepo;
  final MockRoleRepo roleRepo;
  final MockTokenService tokenService;

  TestCompositionRoot()
      : userRepo = MockUserRepo(),
        blogRepo = MockBlogRepo(),
        jwtService = MockJwtService(),
        cryptoHasher = MockPasswordHasher(),
        keystoreRepo = MockKeystoreRepo(),
        roleRepo = MockRoleRepo(),
        tokenService = MockTokenService();

  AuthService get authService => AuthService(
        userRepo: userRepo,
        jwt: jwtService,
        crypto: cryptoHasher,
        tokenService: tokenService,
      );

  Handler get router => buildRouter(
        authService: authService,
        blogRepo: blogRepo,
        jwtService: jwtService,
        userRepo: userRepo,
        keystoreRepo: keystoreRepo,
        roleRepo: roleRepo,
        dbCheck: () async => true,
        cacheCheck: () async => true,
      );
}
