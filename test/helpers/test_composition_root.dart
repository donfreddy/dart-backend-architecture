import 'package:dart_backend_architecture/routes/router.dart';
import 'package:dart_backend_architecture/services/auth_service.dart';
import 'package:dart_backend_architecture/services/blog_service.dart';
import 'package:shelf/shelf.dart';
import '../mocks/mocks.dart';

// Composition Root de test — remplace les implémentations concrètes
// par des mocks sans toucher à la production
final class TestCompositionRoot {
  final MockUserRepo userRepo;
  final MockBlogRepo blogRepo;
  final MockJwtService jwtService;
  final MockCryptoWorker cryptoWorker;
  // final MockCacheService cacheService;
  // final MockNatsService natsService;
  // final MockCryptoWorker cryptoWorker;

  TestCompositionRoot()
      : userRepo = MockUserRepo(),
        blogRepo = MockBlogRepo(),
        jwtService = MockJwtService(),
        cryptoWorker = MockCryptoWorker()
        // cacheService = MockCacheService(),
        // natsService = MockNatsService()
        ;
        
  AuthService get authService => AuthService(
        userRepo: userRepo,
        keystoreRepo: MockKeystoreRepo(),
        jwt: jwtService,
        crypto: cryptoWorker,
      );

  BlogService get blogService => BlogService(
        blogRepo: blogRepo,
        // cache: cacheService,
        // nats: natsService,
      );

  Handler get router => buildRouter(
        authService: authService,
        blogService: blogService,
        jwtService: jwtService,
      );
}
