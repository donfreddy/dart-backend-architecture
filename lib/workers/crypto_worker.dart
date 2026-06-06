import 'package:bcrypt/bcrypt.dart';
import 'package:dart_backend_architecture/core/password_hasher.dart';

final class CryptoSync implements PasswordHasher {
  @override
  Future<String> hashPassword(String plaintext) async => BCrypt.hashpw(
        plaintext,
        BCrypt.gensalt(logRounds: 12),
      );

  @override
  Future<bool> verifyPassword(String plaintext, String hash) async =>
      BCrypt.checkpw(plaintext, hash);

  @override
  Future<void> fakeHash() async {
    BCrypt.hashpw('__fake_password_dba__', BCrypt.gensalt(logRounds: 12));
  }
}
