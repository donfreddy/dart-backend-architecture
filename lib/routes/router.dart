import 'package:dart_backend_architecture/cache/repository/user_cache.dart';
import 'package:dart_backend_architecture/core/jwt/jwt_service.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/keystore_repo.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/role_repo.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/user_repo.dart';
import 'package:dart_backend_architecture/routes/health_handler.dart';
import 'package:dart_backend_architecture/routes/v1/router.dart';
import 'package:dart_backend_architecture/services/auth_service.dart';
import 'package:dart_backend_architecture/services/blog_service.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// Root router wiring liveness/readiness plus versioned APIs.
Handler buildRouter({
  required AuthService authService,
  required BlogService blogService,
  required JwtService jwtService,
  required UserRepo userRepo,
  required KeystoreRepo keystoreRepo,
  required RoleRepo roleRepo,
  required Probe dbCheck,
  required Probe cacheCheck,
  required Probe natsCheck,
  UserCache? userCache,
}) {
  final root = Router();

  // Liveness / readiness: no auth / no versioning
  root.get('/healthz', healthzHandler);
  root.get('/readyz', (Request _) {
    return readyzHandler(
      dbCheck: dbCheck,
      cacheCheck: cacheCheck,
      natsCheck: natsCheck,
    );
  });

  root.mount(
    '/v1',
    buildV1Router(
      authService: authService,
      blogService: blogService,
      jwtService: jwtService,
      userRepo: userRepo,
      keystoreRepo: keystoreRepo,
      roleRepo: roleRepo,
      userCache: userCache,
    ),
  );

  return root.call;
}
