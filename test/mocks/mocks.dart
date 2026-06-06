import 'package:dart_backend_architecture/cache/cache_service.dart';
import 'package:dart_backend_architecture/cache/repository/blog_cache.dart';
import 'package:dart_backend_architecture/core/jwt/jwt_service.dart';
import 'package:dart_backend_architecture/core/password_hasher.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/blog_repo.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/keystore_repo.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/role_repo.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/user_repo.dart';
import 'package:dart_backend_architecture/services/auth_service.dart';
import 'package:dart_backend_architecture/services/token_service.dart';
import 'package:mocktail/mocktail.dart';

class MockUserRepo extends Mock implements UserRepo {}

class MockBlogRepo extends Mock implements BlogRepo {}

class MockKeystoreRepo extends Mock implements KeystoreRepo {}

class MockRoleRepo extends Mock implements RoleRepo {}

class MockJwtService extends Mock implements JwtService {}

class MockPasswordHasher extends Mock implements PasswordHasher {}

class MockBlogCache extends Mock implements BlogCache {}

class MockCacheService extends Mock implements CacheService {}

class MockTokenService extends Mock implements TokenService {}

class MockAuthService extends Mock implements AuthService {}
