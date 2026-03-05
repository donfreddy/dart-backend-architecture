import 'package:dart_backend_architecture/database/model/keystore.dart';
import 'package:dart_backend_architecture/database/model/user.dart';

typedef UserWithKeystore = ({User user, Keystore keystore});

abstract interface class UserRepo {
  Future<User?> findById(String id);
  Future<User?> findByEmail(String email);
  Future<User?> findProfileById(String id);
  Future<User?> findPublicProfileById(String id);

  Future<UserWithKeystore> create(
    User user,
    String accessTokenKey,
    String refreshTokenKey,
    String roleCode,
  );

  Future<UserWithKeystore> update(
    User user,
    String accessTokenKey,
    String refreshTokenKey,
  );

  Future<void> updateInfo(User user);
}
