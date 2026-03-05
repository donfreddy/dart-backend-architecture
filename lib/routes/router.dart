import 'package:dart_backend_architecture/core/jwt/jwt_service.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/keystore_repo.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/role_repo.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/user_repo.dart';
import 'package:dart_backend_architecture/routes/v1/router.dart';
import 'package:dart_backend_architecture/services/auth_service.dart';
import 'package:dart_backend_architecture/services/blog_service.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

Handler buildRouter({
  required AuthService authService,
  required BlogService blogService,
  required JwtService jwtService,
  required UserRepo userRepo,
  required KeystoreRepo keystoreRepo,
  required RoleRepo roleRepo,
}) {
  final root = Router();

  root.mount(
    '/v1',
    buildV1Router(
      authService: authService,
      blogService: blogService,
      jwtService: jwtService,
      userRepo: userRepo,
      keystoreRepo: keystoreRepo,
      roleRepo: roleRepo,
    ),
  );

  return root.call;
}
