import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/core/middleware/auth_middleware.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/user_repo.dart';
import 'package:dart_backend_architecture/helpers/validator.dart';
import 'package:dart_backend_architecture/routes/base_response.dart';
import 'package:dart_backend_architecture/routes/v1/profile/schema.dart';
import 'package:shelf/shelf.dart';

Future<Response> publicProfileByIdHandler(
  Request request,
  String id,
  UserRepo userRepo,
) async {
  final validated = validateSchema(
    profileUserIdSchema,
    {'id': id},
    source: ValidationSource.param,
  );

  final user = await userRepo.findPublicProfileById(validated['id'] as String);
  if (user == null) {
    throw const BadRequestError('User not registered');
  }

  return ok(
    message: 'success',
    data: {
      'name': user.name,
      if (user.profilePicUrl != null) 'profilePicUrl': user.profilePicUrl,
    },
  );
}

Future<Response> myProfileHandler(
  Request request,
  UserRepo userRepo,
) async {
  final authUser = request.authUser;
  final user = await userRepo.findProfileById(authUser.id);
  if (user == null) {
    throw const BadRequestError('User not registered');
  }

  return ok(
    message: 'success',
    data: {
      'name': user.name,
      if (user.profilePicUrl != null) 'profilePicUrl': user.profilePicUrl,
      'roles': user.roles,
    },
  );
}

Future<Response> updateProfileHandler(
  Request request,
  UserRepo userRepo,
) async {
  final authUser = request.authUser;
  final user = await userRepo.findProfileById(authUser.id);
  if (user == null) {
    throw const BadRequestError('User not registered');
  }

  final body = await readJsonBody(request);
  final validated = validateSchema(
    profileUpdateSchema,
    body,
  );

  final updatedUser = user.copyWith(
    name: validated['name'] as String? ?? user.name,
    profilePicUrl: validated['profilePicUrl'] as String? ?? user.profilePicUrl,
  );

  await userRepo.updateInfo(updatedUser);

  return ok(
    message: 'Profile updated',
    data: {
      'name': updatedUser.name,
      if (updatedUser.profilePicUrl != null) 'profilePicUrl': updatedUser.profilePicUrl,
      'roles': updatedUser.roles,
    },
  );
}
