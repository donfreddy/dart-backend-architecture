import 'package:dart_backend_architecture/routes/router.dart';
import 'package:dart_backend_architecture/services/auth_service.dart';
import 'package:dart_backend_architecture/services/blog_service.dart';
import 'package:shelf/shelf.dart';

import '../mocks/mocks.dart';

final class TestCompositionRoot {
  final MockUserRepo userRepo;
  final MockBlogRepo blogRepo;
  final MockJwtService jwtService;
  final MockCryptoWorker cryptoWorker;
  final MockKeystoreRepo keystoreRepo;
  final MockRoleRepo roleRepo;
  final MockTokenService tokenService;

  TestCompositionRoot()
      : userRepo = MockUserRepo(),
        blogRepo = MockBlogRepo(),
        jwtService = MockJwtService(),
        cryptoWorker = MockCryptoWorker(),
        keystoreRepo = MockKeystoreRepo(),
        roleRepo = MockRoleRepo(),
        tokenService = MockTokenService();

  AuthService get authService => AuthService(
        userRepo: userRepo,
        jwt: jwtService,
        crypto: cryptoWorker,
        tokenService: tokenService,
      );

  BlogService get blogService =>
      throw UnimplementedError('BlogService is not used in current unit tests');

  Handler get router => buildRouter(
        authService: authService,
        blogService: blogService,
        jwtService: jwtService,
        userRepo: userRepo,
        keystoreRepo: keystoreRepo,
        roleRepo: roleRepo,
        dbCheck: () async => true,
        cacheCheck: () async => true,
        natsCheck: () async => true,
      );
}
