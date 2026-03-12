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
import 'package:dart_backend_architecture/routes/v1/blog/blog_detail_handler.dart';
import 'package:dart_backend_architecture/routes/v1/blogs/list_handler.dart';
import 'package:dart_backend_architecture/routes/v1/blog/editor_handler.dart';
import 'package:dart_backend_architecture/routes/v1/blog/writer_handler.dart';
import 'package:dart_backend_architecture/routes/v1/profile/profile_handler.dart';
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
  final requireWriter = authorizationMiddleware(
    roleRepo: roleRepo,
    roleCode: RoleCode.writer.value,
  );
  Handler applyEditorAuth(Handler inner) => requireAuth(requireEditor(inner));
  Handler applyWriterAuth(Handler inner) => requireAuth(requireWriter(inner));

  final myProfile = requireAuth((r) => myProfileHandler(r, userRepo));
  final updateProfile = requireAuth((r) => updateProfileHandler(r, userRepo));

  // Auth
  router.post('/signup/basic', (Request r) => signupHandler(r, authService));
  router.post('/login/basic', (Request r) => loginHandler(r, authService));
  router.delete('/logout', (Request r) => logoutHandler(r, authService));
  router.post('/token/refresh', (Request r) => tokenHandler(r, authService));

  // Blogs
  router.get('/blogs/url', (Request r) => blogByUrlHandler(r, blogService));
  router.get(
    '/blogs/id/<id>',
    (Request _, String id) => blogByIdHandler(id, blogService),
  );
  router.get(
    '/blogs/tag/<tag>',
    (Request r, String tag) => blogsByTagHandler(r, tag, blogService),
  );
  router.get(
    '/blogs/author/id/<id>',
    (Request r, String id) =>
        blogsByAuthorIdHandler(r, id, blogService, userRepo),
  );
  router.get(
    '/blogs/latest',
    (Request r) => latestBlogsHandler(r, blogService),
  );
  router.get(
    '/blogs/similar/id/<id>',
    (Request r, String id) => similarBlogsByIdHandler(r, id, blogService),
  );

  // Blog writer (auth + writer role)
  router.post('/blogs/writer', (Request r) {
    return applyWriterAuth((req) => writerCreateBlogHandler(req, blogService))(
      r,
    );
  });
  router.put('/blogs/writer/id/<id>', (Request r, String id) {
    return applyWriterAuth(
      (req) => writerUpdateBlogHandler(req, id, blogService),
    )(r);
  });
  router.put('/blogs/writer/submit/<id>', (Request r, String id) {
    return applyWriterAuth(
      (req) => writerSubmitBlogHandler(req, id, blogService),
    )(r);
  });
  router.put('/blogs/writer/withdraw/<id>', (Request r, String id) {
    return applyWriterAuth(
      (req) => writerWithdrawBlogHandler(req, id, blogService),
    )(r);
  });
  router.delete('/blogs/writer/id/<id>', (Request r, String id) {
    return applyWriterAuth(
      (req) => writerDeleteBlogHandler(req, id, blogService),
    )(r);
  });
  router.get('/blogs/writer/submitted/all', (Request r) {
    return applyWriterAuth(
      (req) => writerSubmittedBlogsHandler(req, blogService),
    )(r);
  });
  router.get('/blogs/writer/published/all', (Request r) {
    return applyWriterAuth(
      (req) => writerPublishedBlogsHandler(req, blogService),
    )(r);
  });
  router.get('/blogs/writer/drafts/all', (Request r) {
    return applyWriterAuth((req) => writerDraftBlogsHandler(req, blogService))(
      r,
    );
  });
  router.get('/blogs/writer/id/<id>', (Request r, String id) {
    return applyWriterAuth(
      (req) => writerBlogByIdHandler(req, id, blogService),
    )(r);
  });

  // Blog editor (auth + editor role)
  router.put('/blogs/editor/publish/<id>', (Request r, String id) {
    return applyEditorAuth((_) => editorPublishBlogHandler(id, blogService))(r);
  });
  router.put('/blogs/editor/unpublish/<id>', (Request r, String id) {
    return applyEditorAuth((_) => editorUnpublishBlogHandler(id, blogService))(
      r,
    );
  });
  router.delete('/blogs/editor/id/<id>', (Request r, String id) {
    return applyEditorAuth((_) => editorDeleteBlogHandler(id, blogService))(r);
  });
  router.get('/blogs/editor/published/all', (Request r) {
    return applyEditorAuth((_) => editorPublishedBlogsHandler(blogService))(r);
  });
  router.get('/blogs/editor/submitted/all', (Request r) {
    return applyEditorAuth((_) => editorSubmittedBlogsHandler(blogService))(r);
  });
  router.get('/blogs/editor/drafts/all', (Request r) {
    return applyEditorAuth((_) => editorDraftBlogsHandler(blogService))(r);
  });
  router.get('/blogs/editor/id/<id>', (Request r, String id) {
    return applyEditorAuth((_) => editorBlogByIdHandler(id, blogService))(r);
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
