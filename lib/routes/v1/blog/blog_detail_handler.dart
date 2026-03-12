import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/core/response/shelf_response_x.dart';
import 'package:dart_backend_architecture/helpers/validator.dart';
import 'package:dart_backend_architecture/routes/v1/blog/schema.dart';
import 'package:dart_backend_architecture/services/blog_service.dart';
import 'package:shelf/shelf.dart';

Future<Response> blogByUrlHandler(
  Request request,
  BlogService blogService,
) async {
  final validated = validateSchema(
    blogUrlQuerySchema,
    request.requestedUri.queryParameters,
    source: ValidationSource.query,
  );

  final endpoint = validateUrlEndpoint(validated['endpoint'] as String);
  final blog = await blogService.findByUrl(endpoint);
  if (blog == null) {
    throw const BadRequestError('Blog do not exists');
  }

  return ok(
    message: 'success',
    data: blog.toJson(),
  );
}

Future<Response> blogByIdHandler(
  String id,
  BlogService blogService,
) async {
  final validated = validateSchema(
    blogIdParamSchema,
    {'id': id},
    source: ValidationSource.param,
  );

  final blog = await blogService.findInfoWithTextById(validated['id'] as String);
  if (blog == null) {
    throw const BadRequestError('Blog do not exists');
  }

  return ok(
    message: 'success',
    data: blog.toJson(),
  );
}
