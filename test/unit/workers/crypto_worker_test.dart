import 'package:dart_backend_architecture/workers/crypto_sync.dart';
import 'package:test/test.dart';

void main() {
  group('CryptoSync', () {
    late CryptoSync cryptoSync;

    setUp(() {
      cryptoSync = CryptoSync();
    });

    test('hashPassword returns a bcrypt hash', () async {
      final hash = await cryptoSync.hashPassword('my-password');

      expect(hash, isA<String>());
      expect(hash.length, greaterThanOrEqualTo(50));
    });

    test('verifyPassword returns true for matching password', () async {
      final hash = await cryptoSync.hashPassword('my-password');
      final valid = await cryptoSync.verifyPassword('my-password', hash);

      expect(valid, isTrue);
    });

    test('verifyPassword returns false for wrong password', () async {
      final hash = await cryptoSync.hashPassword('my-password');
      final valid = await cryptoSync.verifyPassword('wrong-password', hash);

      expect(valid, isFalse);
    });

    test('fakeHash completes without error', () async {
      await expectLater(cryptoSync.fakeHash(), completes);
    });
  });
}
