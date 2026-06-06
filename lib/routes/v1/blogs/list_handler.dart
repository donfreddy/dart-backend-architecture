import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/core/response/shelf_response_x.dart';
import 'package:dart_backend_architecture/database/model/blog.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/user_repo.dart';
import 'package:dart_backend_architecture/helpers/validator.dart';
import 'package:dart_backend_architecture/routes/v1/blog/schema.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/blog_repo.dart';
import 'package:shelf/shelf.dart';

Future<Response> blogsByTagHandler(
  Request request,
  String tag,
  BlogRepo blogRepo,
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

  final result = await blogRepo.findByTagAndPaginated(
    tagValidated['tag'] as String,
    pageNumber,
    limit,
  );

  return okPaginated(    items: result.items.map((Blog b) => b.toJson()).toList(growable: false),
    page: pageNumber,
    limit: limit,
    total: result.total,
  );
}

Future<Response> blogsByAuthorIdHandler(
  Request request,
  String id,
  BlogRepo blogRepo,
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

  final result = await blogRepo.findAllPublishedForAuthor(
    author,
    pageNumber: pageNumber,
    limit: limit,
  );

  return okPaginated(    items: result.items.map((Blog b) => b.toJson()).toList(growable: false),
    page: pageNumber,
    limit: limit,
    total: result.total,
  );
}

Future<Response> latestBlogsHandler(
  Request request,
  BlogRepo blogRepo,
) async {
  final queryValidated = validateSchema(
    blogPaginationQuerySchema,
    request.requestedUri.queryParameters,
    source: ValidationSource.query,
  );

  final pageNumber = queryValidated['pageNumber'] as int;
  final limit = queryValidated['pageItemCount'] as int;

  final result = await blogRepo.findLatestBlogs(pageNumber, limit);

  return okPaginated(    items: result.items.map((Blog b) => b.toJson()).toList(growable: false),
    page: pageNumber,
    limit: limit,
    total: result.total,
  );
}

Future<Response> similarBlogsByIdHandler(
  Request request,
  String id,
  BlogRepo blogRepo,
) async {
  final validated = validateSchema(
    blogIdParamSchema,
    {'id': id},
    source: ValidationSource.param,
  );

  final blog = await blogRepo.findById(validated['id'] as String);
  if (blog == null || !blog.isPublished) {
    throw const BadRequestError('Blog is not available');
  }

  final blogs = await blogRepo.searchSimilarBlogs(blog, 6);
  if (blogs.isEmpty) throw const NoDataError();

  return ok(
    message: 'success',
    data: blogs.map((b) => b.toJson()).toList(growable: false),
  );
}
