import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/core/response/shelf_response_x.dart';
import 'package:dart_backend_architecture/helpers/validator.dart';
import 'package:dart_backend_architecture/routes/v1/blog/schema.dart';
import 'package:dart_backend_architecture/services/blog_service.dart';
import 'package:shelf/shelf.dart';

Future<Response> editorPublishBlogHandler(
  String id,
  BlogService blogService,
) async {
  final validated = validateSchema(
    blogIdParamSchema,
    {'id': id},
    source: ValidationSource.param,
  );

  final blog = await blogService.findBlogAllDataById(validated['id'] as String);
  if (blog == null) throw const BadRequestError('Blog does not exists');

  final published = blog.copyWith(
    isDraft: false,
    isSubmitted: false,
    isPublished: true,
    text: blog.draftText,
    publishedAt: blog.publishedAt ?? DateTime.now().toUtc(),
  );

  await blogService.update(published);
  return ok<Object?>(message: 'Blog published successfully');
}

Future<Response> editorUnpublishBlogHandler(
  String id,
  BlogService blogService,
) async {
  final validated = validateSchema(
    blogIdParamSchema,
    {'id': id},
    source: ValidationSource.param,
  );

  final blog = await blogService.findBlogAllDataById(validated['id'] as String);
  if (blog == null) throw const BadRequestError('Blog does not exists');

  final unpublished = blog.copyWith(
    isDraft: true,
    isSubmitted: false,
    isPublished: false,
  );

  await blogService.update(unpublished);
  return ok<Object?>(message: 'Blog unpublished successfully');
}

Future<Response> editorDeleteBlogHandler(
  String id,
  BlogService blogService,
) async {
  final validated = validateSchema(
    blogIdParamSchema,
    {'id': id},
    source: ValidationSource.param,
  );

  final blog = await blogService.findBlogAllDataById(validated['id'] as String);
  if (blog == null) throw const BadRequestError('Blog does not exists');

  await blogService.update(blog.copyWith(status: false));
  return ok<Object?>(message: 'Blog deleted successfully');
}

Future<Response> editorPublishedBlogsHandler(BlogService blogService) async {
  final blogs = await blogService.findAllPublished();
  return ok(
    message: 'success',
    data: blogs.map((b) => b.toJson()).toList(growable: false),
  );
}

Future<Response> editorSubmittedBlogsHandler(BlogService blogService) async {
  final blogs = await blogService.findAllSubmissions();
  return ok(
    message: 'success',
    data: blogs.map((b) => b.toJson()).toList(growable: false),
  );
}

Future<Response> editorDraftBlogsHandler(BlogService blogService) async {
  final blogs = await blogService.findAllDrafts();
  return ok(
    message: 'success',
    data: blogs.map((b) => b.toJson()).toList(growable: false),
  );
}

Future<Response> editorBlogByIdHandler(
  String id,
  BlogService blogService,
) async {
  final validated = validateSchema(
    blogIdParamSchema,
    {'id': id},
    source: ValidationSource.param,
  );

  final blog = await blogService.findBlogAllDataById(validated['id'] as String);
  if (blog == null) throw const BadRequestError('Blog does not exists');
  if (!blog.isSubmitted && !blog.isPublished) {
    throw const ForbiddenError('This blog is private');
  }

  return ok(
    message: 'success',
    data: blog.toJson(),
  );
}
