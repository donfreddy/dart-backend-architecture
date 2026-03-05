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

  TestCompositionRoot()
      : userRepo = MockUserRepo(),
        blogRepo = MockBlogRepo(),
        jwtService = MockJwtService(),
        cryptoWorker = MockCryptoWorker(),
        keystoreRepo = MockKeystoreRepo();

  AuthService get authService => AuthService(
        userRepo: userRepo,
        keystoreRepo: keystoreRepo,
        jwt: jwtService,
        crypto: cryptoWorker,
      );

  BlogService get blogService => BlogService(
        blogRepo: blogRepo,
      );

  Handler get router => buildRouter(
        authService: authService,
        blogService: blogService,
        jwtService: jwtService,
        userRepo: userRepo,
        keystoreRepo: keystoreRepo,
      );
}
