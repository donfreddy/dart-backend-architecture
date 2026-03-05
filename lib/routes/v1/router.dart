import 'package:dart_backend_architecture/core/jwt/jwt_service.dart';
import 'package:dart_backend_architecture/routes/v1/access/logout_handler.dart';
import 'package:dart_backend_architecture/routes/v1/access/login_handler.dart';
import 'package:dart_backend_architecture/routes/v1/access/signup_handler.dart';
import 'package:dart_backend_architecture/routes/v1/access/token_handler.dart';
import 'package:dart_backend_architecture/services/auth_service.dart';
import 'package:dart_backend_architecture/services/blog_service.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

Handler buildV1Router({
  required AuthService authService,
  required BlogService blogService,
  required JwtService jwtService,
}) {
  final router = Router();

  // Auth
  router.post('/signup/basic', (Request r) => signupHandler(r, authService));
  router.post('/login/basic', (Request r) => loginHandler(r, authService));
  router.delete('/logout', (Request r) => logoutHandler(r, authService));
  router.post('/token/refresh', (Request r) => tokenHandler(r, authService));

  // Blogs
  router.get('/blogs', (r) => listBlogsHandler(r, blogService));
  router.get('/blogs/<id>', (r, id) => blogDetailHandler(r, id, blogService));

  // Blog writer
  router.post('/blog', (r) => writerCreateHandler(r, blogService));
  router.put('/blog/<id>', (r, id) => writerUpdateHandler(r, id, blogService));

  // Blog editor
  router.put('/blog/<id>/submit', (r, id) => editorSubmitHandler(r, id, blogService));
  router.put('/blog/<id>/publish', (r, id) => editorPublishHandler(r, id, blogService));

  // Profile
  router.get('/profile/my', (r) => myProfileHandler(r, authService));

  return router.call;
}
