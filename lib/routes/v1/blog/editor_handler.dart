import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/core/response/shelf_response_x.dart';
import 'package:dart_backend_architecture/database/model/blog.dart';
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

  final blog = await blogService.findById(validated['id'] as String);
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

  final blog = await blogService.findById(validated['id'] as String);
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

  final blog = await blogService.findById(validated['id'] as String);
  if (blog == null) throw const BadRequestError('Blog does not exists');

  await blogService.update(blog.copyWith(status: false));
  return ok<Object?>(message: 'Blog deleted successfully');
}

Future<Response> editorPublishedBlogsHandler(
  Request request,
  BlogService blogService,
) async {
  final query = blogPaginationQuerySchema.safeParse(
    request.requestedUri.queryParameters,
  );
  final pageNumber = query.isSuccess
      ? query.value['pageNumber'] as int
      : 1;
  final limit = query.isSuccess
      ? query.value['pageItemCount'] as int
      : 10;

  final result = await blogService.findAllPublished(
    pageNumber: pageNumber,
    limit: limit,
  );
  return okPaginated<Map<String, Object?>>(
    message: 'success',
    items: result.items.map((Blog b) => b.toJson()).toList(growable: false),
    page: pageNumber,
    limit: limit,
    total: result.total,
  );
}

Future<Response> editorSubmittedBlogsHandler(
  Request request,
  BlogService blogService,
) async {
  final query = blogPaginationQuerySchema.safeParse(
    request.requestedUri.queryParameters,
  );
  final pageNumber = query.isSuccess
      ? query.value['pageNumber'] as int
      : 1;
  final limit = query.isSuccess
      ? query.value['pageItemCount'] as int
      : 10;

  final result = await blogService.findAllSubmissions(
    pageNumber: pageNumber,
    limit: limit,
  );
  return okPaginated<Map<String, Object?>>(
    message: 'success',
    items: result.items.map((Blog b) => b.toJson()).toList(growable: false),
    page: pageNumber,
    limit: limit,
    total: result.total,
  );
}

Future<Response> editorDraftBlogsHandler(
  Request request,
  BlogService blogService,
) async {
  final query = blogPaginationQuerySchema.safeParse(
    request.requestedUri.queryParameters,
  );
  final pageNumber = query.isSuccess
      ? query.value['pageNumber'] as int
      : 1;
  final limit = query.isSuccess
      ? query.value['pageItemCount'] as int
      : 10;

  final result = await blogService.findAllDrafts(
    pageNumber: pageNumber,
    limit: limit,
  );
  return okPaginated<Map<String, Object?>>(
    message: 'success',
    items: result.items.map((Blog b) => b.toJson()).toList(growable: false),
    page: pageNumber,
    limit: limit,
    total: result.total,
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

  final blog = await blogService.findById(validated['id'] as String);
  if (blog == null) throw const BadRequestError('Blog does not exists');
  if (!blog.isSubmitted && !blog.isPublished) {
    throw const ForbiddenError('This blog is private');
  }

  return ok(
    message: 'success',
    data: blog.toJson(),
  );
}
