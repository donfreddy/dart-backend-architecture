import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/core/response/shelf_response_x.dart';
import 'package:dart_backend_architecture/database/model/blog.dart';
import 'package:dart_backend_architecture/helpers/validator.dart';
import 'package:dart_backend_architecture/routes/v1/blog/schema.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/blog_repo.dart';
import 'package:shelf/shelf.dart';

Future<Response> editorPublishBlogHandler(
  String id,
  BlogRepo blogRepo,
) async {
  final validated = validateSchema(
    blogIdParamSchema,
    {'id': id},
    source: ValidationSource.param,
  );

  final blog = await blogRepo.findById(validated['id'] as String);
  if (blog == null) throw const BadRequestError('Blog does not exists');

  final published = blog.copyWith(
    isDraft: false,
    isSubmitted: false,
    isPublished: true,
    text: blog.draftText,
    publishedAt: blog.publishedAt ?? DateTime.now().toUtc(),
  );

  await blogRepo.update(published);
  return ok(message: 'Blog published successfully');
}

Future<Response> editorUnpublishBlogHandler(
  String id,
  BlogRepo blogRepo,
) async {
  final validated = validateSchema(
    blogIdParamSchema,
    {'id': id},
    source: ValidationSource.param,
  );

  final blog = await blogRepo.findById(validated['id'] as String);
  if (blog == null) throw const BadRequestError('Blog does not exists');

  final unpublished = blog.copyWith(
    isDraft: true,
    isSubmitted: false,
    isPublished: false,
  );

  await blogRepo.update(unpublished);
  return ok(message: 'Blog unpublished successfully');
}

Future<Response> editorDeleteBlogHandler(
  String id,
  BlogRepo blogRepo,
) async {
  final validated = validateSchema(
    blogIdParamSchema,
    {'id': id},
    source: ValidationSource.param,
  );

  final blog = await blogRepo.findById(validated['id'] as String);
  if (blog == null) throw const BadRequestError('Blog does not exists');

  await blogRepo.update(blog.copyWith(status: false));
  return ok(message: 'Blog deleted successfully');
}

Future<Response> editorPublishedBlogsHandler(
  Request request,
  BlogRepo blogRepo,
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

  final result = await blogRepo.findAllPublished(
    pageNumber: pageNumber,
    limit: limit,
  );
  return okPaginated(    items: result.items.map((Blog b) => b.toJson()).toList(growable: false),
    page: pageNumber,
    limit: limit,
    total: result.total,
  );
}

Future<Response> editorSubmittedBlogsHandler(
  Request request,
  BlogRepo blogRepo,
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

  final result = await blogRepo.findAllSubmissions(
    pageNumber: pageNumber,
    limit: limit,
  );
  return okPaginated(    items: result.items.map((Blog b) => b.toJson()).toList(growable: false),
    page: pageNumber,
    limit: limit,
    total: result.total,
  );
}

Future<Response> editorDraftBlogsHandler(
  Request request,
  BlogRepo blogRepo,
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

  final result = await blogRepo.findAllDrafts(
    pageNumber: pageNumber,
    limit: limit,
  );
  return okPaginated(    items: result.items.map((Blog b) => b.toJson()).toList(growable: false),
    page: pageNumber,
    limit: limit,
    total: result.total,
  );
}

Future<Response> editorBlogByIdHandler(
  String id,
  BlogRepo blogRepo,
) async {
  final validated = validateSchema(
    blogIdParamSchema,
    {'id': id},
    source: ValidationSource.param,
  );

  final blog = await blogRepo.findById(validated['id'] as String);
  if (blog == null) throw const BadRequestError('Blog does not exists');
  if (!blog.isSubmitted && !blog.isPublished) {
    throw const ForbiddenError('This blog is private');
  }

  return ok(
    message: 'success',
    data: blog.toJson(),
  );
}
