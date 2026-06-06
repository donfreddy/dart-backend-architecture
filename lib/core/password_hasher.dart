abstract interface class PasswordHasher {
  Future<String> hashPassword(String plaintext);
  Future<bool> verifyPassword(String plaintext, String hash);
  Future<void> fakeHash();
}
