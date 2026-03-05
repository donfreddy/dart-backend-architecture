import 'package:dart_backend_architecture/core/jwt/jwt_service.dart';
import 'package:dart_backend_architecture/core/middleware/authorization_middleware.dart';
import 'package:dart_backend_architecture/core/middleware/auth_middleware.dart';
import 'package:dart_backend_architecture/database/model/role.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/keystore_repo.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/role_repo.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/user_repo.dart';
import 'package:dart_backend_architecture/routes/v1/access/logout_handler.dart';
import 'package:dart_backend_architecture/routes/v1/access/login_handler.dart';
import 'package:dart_backend_architecture/routes/v1/access/signup_handler.dart';
import 'package:dart_backend_architecture/routes/v1/access/token_handler.dart';
import 'package:dart_backend_architecture/routes/v1/blog/blog_detail.dart';
import 'package:dart_backend_architecture/routes/v1/blog/blog_list.dart';
import 'package:dart_backend_architecture/routes/v1/blog/editor.dart';
import 'package:dart_backend_architecture/routes/v1/profile/user.dart';
import 'package:dart_backend_architecture/services/auth_service.dart';
import 'package:dart_backend_architecture/services/blog_service.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

Handler buildV1Router({
  required AuthService authService,
  required BlogService blogService,
  required JwtService jwtService,
  required UserRepo userRepo,
  required KeystoreRepo keystoreRepo,
  required RoleRepo roleRepo,
}) {
  final router = Router();
  final requireAuth = authMiddleware(
    jwtService: jwtService,
    userRepo: userRepo,
    keystoreRepo: keystoreRepo,
  );
  final requireEditor = authorizationMiddleware(
    roleRepo: roleRepo,
    roleCode: RoleCode.editor.value,
  );
  Handler applyEditorAuth(Handler inner) => requireAuth(requireEditor(inner));

  final myProfile = requireAuth((r) => myProfileHandler(r, userRepo));
  final updateProfile = requireAuth((r) => updateProfileHandler(r, userRepo));

  // Auth
  router.post('/signup/basic', (Request r) => signupHandler(r, authService));
  router.post('/login/basic', (Request r) => loginHandler(r, authService));
  router.delete('/logout', (Request r) => logoutHandler(r, authService));
  router.post('/token/refresh', (Request r) => tokenHandler(r, authService));

  // Blogs
  router.get('/blogs/url', (Request r) => blogByUrlHandler(r, blogService));
  router.get('/blogs/id/<id>', (Request r, String id) => blogByIdHandler(r, id, blogService));
  router.get('/blogs/tag/<tag>', (Request r, String tag) => blogsByTagHandler(r, tag, blogService));
  router.get(
    '/blogs/author/id/<id>',
    (Request r, String id) => blogsByAuthorIdHandler(r, id, blogService, userRepo),
  );
  router.get('/blogs/latest', (Request r) => latestBlogsHandler(r, blogService));
  router.get('/blogs/similar/id/<id>', (Request r, String id) => similarBlogsByIdHandler(r, id, blogService));

  // Blog writer
  // router.post('/blog', (r) => writerCreateHandler(r, blogService));
  // router.put('/blog/<id>', (r, id) => writerUpdateHandler(r, id, blogService));

  // Blog editor (auth + editor role)
  router.put('/blogs/editor/publish/<id>', (Request r, String id) {
    return applyEditorAuth((req) => editorPublishBlogHandler(req, id, blogService))(r);
  });
  router.put('/blogs/editor/unpublish/<id>', (Request r, String id) {
    return applyEditorAuth((req) => editorUnpublishBlogHandler(req, id, blogService))(r);
  });
  router.delete('/blogs/editor/id/<id>', (Request r, String id) {
    return applyEditorAuth((req) => editorDeleteBlogHandler(req, id, blogService))(r);
  });
  router.get('/blogs/editor/published/all', (Request r) {
    return applyEditorAuth((req) => editorPublishedBlogsHandler(req, blogService))(r);
  });
  router.get('/blogs/editor/submitted/all', (Request r) {
    return applyEditorAuth((req) => editorSubmittedBlogsHandler(req, blogService))(r);
  });
  router.get('/blogs/editor/drafts/all', (Request r) {
    return applyEditorAuth((req) => editorDraftBlogsHandler(req, blogService))(r);
  });
  router.get('/blogs/editor/id/<id>', (Request r, String id) {
    return applyEditorAuth((req) => editorBlogByIdHandler(req, id, blogService))(r);
  });

  // Profile
  router.get(
    '/profile/public/id/<id>',
    (Request r, String id) => publicProfileByIdHandler(r, id, userRepo),
  );
  router.get('/profile/my', myProfile);
  router.put('/profile', updateProfile);

  return router.call;
}
