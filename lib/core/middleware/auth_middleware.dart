import 'package:dart_backend_architecture/cache/repository/user_cache.dart';
import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/core/jwt/jwt_service.dart';
import 'package:dart_backend_architecture/core/middleware/schema.dart';
import 'package:dart_backend_architecture/core/request_context_keys.dart';
import 'package:dart_backend_architecture/helpers/validator.dart';
import 'package:dart_backend_architecture/database/model/keystore.dart';
import 'package:dart_backend_architecture/database/model/user.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/keystore_repo.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/user_repo.dart';
import 'package:shelf/shelf.dart';

Middleware authMiddleware({
  required JwtService jwtService,
  required UserRepo userRepo,
  required KeystoreRepo keystoreRepo,
  UserCache? userCache,
}) {
  return (Handler inner) {
    return (Request request) async {
      final headerValidated = validateSchema(
        authHeaderSchema,
        {'authorization': request.headers['authorization']},
        source: ValidationSource.header,
      );

      final accessToken =
          validateAuthBearer(headerValidated['authorization'] as String);

      try {
        final payload = jwtService.validate(accessToken);
        _validateTokenData(payload);

        final user = await _resolveUser(
          userId: payload.sub,
          userRepo: userRepo,
          userCache: userCache,
        );

        final keystore = await _resolveKeystore(
          user: user,
          primaryKey: payload.prm,
          keystoreRepo: keystoreRepo,
          userCache: userCache,
        );

        return inner(
          request.change(
            context: {
              ...request.context,
              RequestContextKeys.accessToken: accessToken,
              RequestContextKeys.userPayload: payload,
              RequestContextKeys.authUser: user,
              RequestContextKeys.authKeystore: keystore,
            },
          ),
        );
      } on TokenExpiredError catch (e) {
        throw AccessTokenError(e.message);
      }
    };
  };
}

Future<User> _resolveUser({
  required String userId,
  required UserRepo userRepo,
  UserCache? userCache,
}) async {
  if (userCache != null) {
    final cached = await userCache.findProfile(userId);
    if (cached != null) return cached;
  }

  final user = await userRepo.findById(userId);
  if (user == null) throw const AuthFailureError('User not registered');

  if (userCache != null) await userCache.saveProfile(user);
  return user;
}

Future<Keystore> _resolveKeystore({
  required User user,
  required String primaryKey,
  required KeystoreRepo keystoreRepo,
  UserCache? userCache,
}) async {
  if (userCache != null) {
    final cached = await userCache.findKeystore(user.id, primaryKey);
    if (cached != null) return cached;
  }

  final keystore = await keystoreRepo.findForKey(user, primaryKey);
  if (keystore == null) throw const AuthFailureError('Invalid access token');

  if (userCache != null) await userCache.saveKeystore(user.id, keystore);
  return keystore;
}

void _validateTokenData(JwtPayload payload) {
  if (payload.sub.isEmpty ||
      payload.prm.isEmpty ||
      payload.iss.isEmpty ||
      payload.aud.isEmpty) {
    throw const AuthFailureError('Invalid access token');
  }
}

extension AuthenticatedRequest on Request {
  String get accessToken {
    final token = context[RequestContextKeys.accessToken];
    if (token is String && token.isNotEmpty) return token;
    throw StateError('access_token not found in request context');
  }

  JwtPayload get userPayload {
    final payload = context[RequestContextKeys.userPayload];
    if (payload is JwtPayload) return payload;
    throw StateError('user_payload not found in request context');
  }

  User get authUser {
    final user = context[RequestContextKeys.authUser];
    if (user is User) return user;
    throw StateError('auth_user not found in request context');
  }

  Keystore get authKeystore {
    final keystore = context[RequestContextKeys.authKeystore];
    if (keystore is Keystore) return keystore;
    throw StateError('auth_keystore not found in request context');
  }
}
