import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/core/jwt/jwt_service.dart';
import 'package:dart_backend_architecture/core/middleware/schema.dart';
import 'package:dart_backend_architecture/helpers/validator.dart';
import 'package:dart_backend_architecture/database/model/keystore.dart';
import 'package:dart_backend_architecture/database/model/user.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/keystore_repo.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/user_repo.dart';
import 'package:shelf/shelf.dart';

const userPayloadKey = 'user_payload';
const accessTokenKey = 'access_token';
const authUserKey = 'auth_user';
const authKeystoreKey = 'auth_keystore';

Middleware authMiddleware({
  required JwtService jwtService,
  required UserRepo userRepo,
  required KeystoreRepo keystoreRepo,
}) {
  return (Handler inner) {
    return (Request request) async {
      final headerValidated = validateSchema(
        authHeaderSchema,
        {'authorization': request.headers['authorization']},
        source: ValidationSource.header,
      );

      final accessToken = validateAuthBearer(headerValidated['authorization'] as String);

      try {
        final payload = jwtService.validate(accessToken);
        _validateTokenData(payload);

        final user = await userRepo.findById(payload.sub);
        if (user == null) {
          throw const AuthFailureError('User not registered');
        }

        final keystore = await keystoreRepo.findForKey(user, payload.prm);
        if (keystore == null) {
          throw const AuthFailureError('Invalid access token');
        }

        return inner(
          request.change(
            context: {
              ...request.context,
              accessTokenKey: accessToken,
              userPayloadKey: payload,
              authUserKey: user,
              authKeystoreKey: keystore,
            },
          ),
        );
      } on TokenExpiredError catch (e) {
        throw AccessTokenError(e.message);
      }
    };
  };
}

void _validateTokenData(JwtPayload payload) {
  if (payload.sub.isEmpty || payload.prm.isEmpty || payload.iss.isEmpty || payload.aud.isEmpty) {
    throw const AuthFailureError('Invalid access token');
  }
}

extension AuthenticatedRequest on Request {
  String get accessToken {
    final token = context[accessTokenKey];
    if (token is String && token.isNotEmpty) return token;
    throw StateError('access_token not found in request context');
  }

  JwtPayload get userPayload {
    final payload = context[userPayloadKey];
    if (payload is JwtPayload) return payload;
    throw StateError('user_payload not found in request context');
  }

  User get authUser {
    final user = context[authUserKey];
    if (user is User) return user;
    throw StateError('auth_user not found in request context');
  }

  Keystore get authKeystore {
    final keystore = context[authKeystoreKey];
    if (keystore is Keystore) return keystore;
    throw StateError('auth_keystore not found in request context');
  }
}
