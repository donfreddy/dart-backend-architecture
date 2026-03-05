import 'package:dart_backend_architecture/core/jwt/jwt_service.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/blog_repo.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/keystore_repo.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/user_repo.dart';
import 'package:mocktail/mocktail.dart';

class MockUserRepo extends Mock implements UserRepo {}
class MockBlogRepo extends Mock implements BlogRepo {}
class MockKeystoreRepo extends Mock implements KeystoreRepo {}
class MockJwtService extends Mock implements JwtService {}
// class MockCacheService extends Mock implements CacheService {}
// class MockNatsService extends Mock implements NatsService {}
// class MockCryptoWorker extends Mock implements CryptoWorker {}
