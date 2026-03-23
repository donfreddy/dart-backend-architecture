import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/core/middleware/auth_middleware.dart';
import 'package:dart_backend_architecture/core/response/shelf_response_x.dart';
import 'package:dart_backend_architecture/database/model/blog.dart';
import 'package:dart_backend_architecture/helpers/validator.dart';
import 'package:dart_backend_architecture/routes/v1/blog/schema.dart';
import 'package:dart_backend_architecture/services/blog_service.dart';
import 'package:shelf/shelf.dart';

String _formatEndpoint(String endpoint) =>
    endpoint.replaceAll(RegExp(r'\s+'), '').replaceAll('/', '-');

Future<Response> writerCreateBlogHandler(
  Request request,
  BlogService blogService,
) async {
  final body = await readJsonBody(request);
  final validated = validateSchema(blogCreateSchema, body);

  final authUser = request.authUser;
  final endpoint =
      _formatEndpoint(validateUrlEndpoint(validated['blogUrl'] as String));

  final existingByUrl = await blogService.findUrlIfExists(endpoint);
  if (existingByUrl != null) {
    throw const BadRequestError('Blog with this url already exists');
  }

  final created = await blogService.create(
    Blog(
      title: validated['title'] as String,
      description: validated['description'] as String,
      draftText: validated['text'] as String,
      tags: (validated['tags'] as List<dynamic>).cast<String>(),
      author: authUser,
      blogUrl: endpoint,
      imgUrl: validated['imgUrl'] as String?,
      score: validated['score'] as num,
      isSubmitted: false,
      isDraft: true,
      isPublished: false,
      status: true,
      createdBy: authUser,
      updatedBy: authUser,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    ),
  );
  return ok(
    message: 'Blog created successfully',
    data: created.toJson(),
  );
}

Future<Response> writerUpdateBlogHandler(
  Request request,
  String id,
  BlogService blogService,
) async {
  final validatedParams = validateSchema(
    blogIdParamSchema,
    {'id': id},
    source: ValidationSource.param,
  );
  final body = await readJsonBody(request);
  final validatedBody = validateSchema(blogUpdateSchema, body);

  final authUser = request.authUser;
  final blog =
      await blogService.findBlogAllDataById(validatedParams['id'] as String);
  if (blog == null) throw const BadRequestError('Blog does not exists');
  if (blog.author.id != authUser.id) {
    throw const ForbiddenError("You don't have necessary permissions");
  }

  var updated = blog;

  final blogUrl = validatedBody['blog_url'] as String?;
  if (blogUrl != null) {
    final endpoint = _formatEndpoint(validateUrlEndpoint(blogUrl));
    final existingByUrl = await blogService.findUrlIfExists(endpoint);
    if (existingByUrl != null && existingByUrl.id != blog.id) {
      throw const BadRequestError('Blog URL already used');
    }
    updated = updated.copyWith(blogUrl: endpoint);
  }

  updated = updated.copyWith(
    title: validatedBody['title'] as String? ?? updated.title,
    description: validatedBody['description'] as String? ?? updated.description,
    draftText: validatedBody['text'] as String? ?? updated.draftText,
    tags: (validatedBody['tags'] as List<dynamic>?)?.cast<String>() ??
        updated.tags,
    imgUrl: validatedBody['img_url'] as String? ?? updated.imgUrl,
    score: validatedBody['score'] as num? ?? updated.score,
    updatedBy: authUser,
  );

  await blogService.update(updated);
  return ok(
    message: 'Blog updated successfully',
    data: updated.toJson(),
  );
}

Future<Response> writerSubmitBlogHandler(
  Request request,
  String id,
  BlogService blogService,
) async {
  final validated = validateSchema(
    blogIdParamSchema,
    {'id': id},
    source: ValidationSource.param,
  );

  final authUser = request.authUser;
  final blog = await blogService.findBlogAllDataById(validated['id'] as String);
  if (blog == null) throw const BadRequestError('Blog does not exists');
  if (blog.author.id != authUser.id) {
    throw const ForbiddenError("You don't have necessary permissions");
  }

  await blogService.update(
    blog.copyWith(
      isSubmitted: true,
      isDraft: false,
      updatedBy: authUser,
    ),
  );

  return ok<Object?>(message: 'Blog submitted successfully');
}

Future<Response> writerWithdrawBlogHandler(
  Request request,
  String id,
  BlogService blogService,
) async {
  final validated = validateSchema(
    blogIdParamSchema,
    {'id': id},
    source: ValidationSource.param,
  );

  final authUser = request.authUser;
  final blog = await blogService.findBlogAllDataById(validated['id'] as String);
  if (blog == null) throw const BadRequestError('Blog does not exists');
  if (blog.author.id != authUser.id) {
    throw const ForbiddenError("You don't have necessary permissions");
  }

  await blogService.update(
    blog.copyWith(
      isSubmitted: false,
      isDraft: true,
      updatedBy: authUser,
    ),
  );

  return ok<Object?>(message: 'Blog withdrawn successfully');
}

Future<Response> writerDeleteBlogHandler(
  Request request,
  String id,
  BlogService blogService,
) async {
  final validated = validateSchema(
    blogIdParamSchema,
    {'id': id},
    source: ValidationSource.param,
  );

  final authUser = request.authUser;
  final blog = await blogService.findBlogAllDataById(validated['id'] as String);
  if (blog == null) throw const BadRequestError('Blog does not exists');
  if (blog.author.id != authUser.id) {
    throw const ForbiddenError("You don't have necessary permissions");
  }

  final updated = blog.isPublished
      ? blog.copyWith(
          isDraft: false,
          draftText: blog.text,
          updatedBy: authUser,
        )
      : blog.copyWith(
          status: false,
          updatedBy: authUser,
        );

  await blogService.update(updated);
  return ok<Object?>(message: 'Blog deleted successfully');
}

Future<Response> writerSubmittedBlogsHandler(
  Request request,
  BlogService blogService,
) async {
  final blogs = await blogService.findAllSubmissionsForWriter(request.authUser);
  return ok(
    message: 'success',
    data: blogs.map((b) => b.toJson()).toList(growable: false),
  );
}

Future<Response> writerPublishedBlogsHandler(
  Request request,
  BlogService blogService,
) async {
  final blogs = await blogService.findAllPublishedForWriter(request.authUser);
  return ok(
    message: 'success',
    data: blogs.map((b) => b.toJson()).toList(growable: false),
  );
}

Future<Response> writerDraftBlogsHandler(
  Request request,
  BlogService blogService,
) async {
  final blogs = await blogService.findAllDraftsForWriter(request.authUser);
  return ok(
    message: 'success',
    data: blogs.map((b) => b.toJson()).toList(growable: false),
  );
}

Future<Response> writerBlogByIdHandler(
  Request request,
  String id,
  BlogService blogService,
) async {
  final validated = validateSchema(
    blogIdParamSchema,
    {'id': id},
    source: ValidationSource.param,
  );

  final authUser = request.authUser;
  final blog = await blogService.findBlogAllDataById(validated['id'] as String);
  if (blog == null) throw const BadRequestError('Blog does not exists');
  if (blog.author.id != authUser.id) {
    throw const ForbiddenError("You don't have necessary permissions");
  }

  return ok(
    message: 'success',
    data: blog.toJson(),
  );
}
