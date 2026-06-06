import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/core/response/shelf_response_x.dart';
import 'package:dart_backend_architecture/database/model/blog.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/user_repo.dart';
import 'package:dart_backend_architecture/helpers/validator.dart';
import 'package:dart_backend_architecture/routes/v1/blog/schema.dart';
import 'package:dart_backend_architecture/services/blog_service.dart';
import 'package:shelf/shelf.dart';

Future<Response> blogsByTagHandler(
  Request request,
  String tag,
  BlogService blogService,
) async {
  final tagValidated = validateSchema(
    blogTagParamSchema,
    {'tag': tag},
    source: ValidationSource.param,
  );
  final queryValidated = validateSchema(
    blogPaginationQuerySchema,
    request.requestedUri.queryParameters,
    source: ValidationSource.query,
  );

  final pageNumber = queryValidated['pageNumber'] as int;
  final limit = queryValidated['pageItemCount'] as int;

  final result = await blogService.findByTagAndPaginated(
    tagValidated['tag'] as String,
    pageNumber,
    limit,
  );

  return okPaginated<Map<String, Object?>>(
    message: 'success',
    items: result.items.map((Blog b) => b.toJson()).toList(growable: false),
    page: pageNumber,
    limit: limit,
    total: result.total,
  );
}

Future<Response> blogsByAuthorIdHandler(
  Request request,
  String id,
  BlogService blogService,
  UserRepo userRepo,
) async {
  final validated = validateSchema(
    authorIdParamSchema,
    {'id': id},
    source: ValidationSource.param,
  );

  final query = blogPaginationQuerySchema.safeParse(
    request.requestedUri.queryParameters,
  );
  final pageNumber = query.isSuccess
      ? query.value['pageNumber'] as int
      : 1;
  final limit = query.isSuccess
      ? query.value['pageItemCount'] as int
      : 10;

  final author =
      await userRepo.findPublicProfileById(validated['id'] as String);
  if (author == null) throw const BadRequestError('User not registered');

  final result = await blogService.findAllPublishedForAuthor(
    author,
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

Future<Response> latestBlogsHandler(
  Request request,
  BlogService blogService,
) async {
  final queryValidated = validateSchema(
    blogPaginationQuerySchema,
    request.requestedUri.queryParameters,
    source: ValidationSource.query,
  );

  final pageNumber = queryValidated['pageNumber'] as int;
  final limit = queryValidated['pageItemCount'] as int;

  final result = await blogService.findLatestBlogs(pageNumber, limit);

  return okPaginated<Map<String, Object?>>(
    message: 'success',
    items: result.items.map((Blog b) => b.toJson()).toList(growable: false),
    page: pageNumber,
    limit: limit,
    total: result.total,
  );
}

Future<Response> similarBlogsByIdHandler(
  Request request,
  String id,
  BlogService blogService,
) async {
  final validated = validateSchema(
    blogIdParamSchema,
    {'id': id},
    source: ValidationSource.param,
  );

  final blog = await blogService.findBlogAllDataById(validated['id'] as String);
  if (blog == null || !blog.isPublished) {
    throw const BadRequestError('Blog is not available');
  }

  final blogs = await blogService.searchSimilarBlogs(blog, 6);
  if (blogs.isEmpty) throw const NoDataError();

  return ok(
    message: 'success',
    data: blogs.map((b) => b.toJson()).toList(growable: false),
  );
}
