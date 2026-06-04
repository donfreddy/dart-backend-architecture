import 'package:dart_backend_architecture/workers/crypto_worker.dart';
import 'package:test/test.dart';

void main() {
  group('CryptoWorker', () {
    late CryptoWorker worker;

    setUp(() async {
      worker = await CryptoWorker.spawn();
    });

    tearDown(() async {
      await worker.dispose();
    });

    test('hashPassword returns a bcrypt hash', () async {
      final hash = await worker.hashPassword('my-password');

      expect(hash, isA<String>());
      expect(hash.length, greaterThanOrEqualTo(50));
    });

    test('verifyPassword returns true for matching password', () async {
      final hash = await worker.hashPassword('my-password');
      final valid = await worker.verifyPassword('my-password', hash);

      expect(valid, isTrue);
    });

    test('verifyPassword returns false for wrong password', () async {
      final hash = await worker.hashPassword('my-password');
      final valid = await worker.verifyPassword('wrong-password', hash);

      expect(valid, isFalse);
    });

    test('fakeHash completes without error', () async {
      await expectLater(worker.fakeHash(), completes);
    });
  });
}
