import 'package:dart_backend_architecture/core/jwt/jwt_service.dart';
import 'package:dart_backend_architecture/routes/v1/router.dart';
import 'package:dart_backend_architecture/services/auth_service.dart';
import 'package:dart_backend_architecture/services/blog_service.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

Handler buildRouter({
  required AuthService authService,
  required BlogService blogService,
  required JwtService jwtService,
}) {
  final root = Router();

  root.mount(
    '/v1',
    buildV1Router(
      authService: authService,
      blogService: blogService,
      jwtService: jwtService,
    ),
  );

  return root.call;
}
