import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/core/jwt/jwt_service.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:test/test.dart';

void main() {
  // Test keys committed for development and testing only.
  // Never use these in production — generate your own.
  const privatePem = '''-----BEGIN RSA PRIVATE KEY-----
MIIBOgIBAAJBAJ6P+APtBxacEuI6n3PbdIDsLR2/uj/FVincMBYKBtpc3jBL/JNp
qX10mmdkOpOv6Jh0vE314q9Zg88jSNjus9kCAwEAAQJAZ3W09IrSVzRbNfXeWPBW
olB4V7LkSfvu7r1XOuor8ooi7cHyHAmaYu7LmcG41wE37BKkUG5+PTW3Q6qyIOqq
IQIhANERd9yfuV57Tvv4eNHeIBPzpa2PUYCkOqYng9cfPR4dAiEAwigUJYUCeY6i
SwlLcV+eFdGDd9n10iy3v9hXmyGUr+0CIDO8mObV9+9zoFYmZO+6gkGtt8A9iTPG
cGURvkSMDHnZAiBy65QZLSRs3M8VCPhdr9H7ahqd6yYEdDGC3UPlb7f5dQIhAM6Q
HzyFgXw46pPHHfiTH5bNt6Ms97plq1waZcwMtwfT
-----END RSA PRIVATE KEY-----''';

  const publicPem = '''-----BEGIN RSA PUBLIC KEY-----
MEgCQQCej/gD7QcWnBLiOp9z23SA7C0dv7o/xVYp3DAWCgbaXN4wS/yTaal9dJpn
ZDqTr+iYdLxN9eKvWYPPI0jY7rPZAgMBAAE=
-----END RSA PUBLIC KEY-----''';

  JwtService makeService() => JwtService(
        privateKeyPem: privatePem,
        publicKeyPem: publicPem,
      );

  String signJwt(Map<String, dynamic> payload, {bool expired = false}) {
    final jwt = JWT(payload);
    if (expired) {
      return jwt.sign(
        RSAPrivateKey(privatePem),
        algorithm: JWTAlgorithm.RS256,
        expiresIn: const Duration(hours: -1),
      );
    }
    return jwt.sign(
      RSAPrivateKey(privatePem),
      algorithm: JWTAlgorithm.RS256,
      expiresIn: const Duration(hours: 1),
    );
  }

  group('JwtService', () {
    late JwtService service;

    setUp(() {
      service = makeService();
    });

    test('validate returns payload for valid token', () async {
      final token = signJwt({
        'sub': 'u-1',
        'prm': 'key-1',
        'iss': 'test',
        'aud': 'test',
        'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });

      final payload = await service.validate(token);

      expect(payload.sub, 'u-1');
      expect(payload.prm, 'key-1');
    });

    test('validate throws TokenExpiredError for expired token', () async {
      final token = signJwt(
        {
          'sub': 'u-1',
          'prm': 'key-1',
          'iss': 'test',
          'aud': 'test',
        },
        expired: true,
      );

      await expectLater(
        service.validate(token),
        throwsA(isA<TokenExpiredError>()),
      );
    });

    test('validate throws BadTokenError for invalid token', () async {
      await expectLater(
        service.validate('invalid-token'),
        throwsA(isA<BadTokenError>()),
      );
    });

    test('decode returns payload for expired token', () async {
      final token = signJwt(
        {
          'sub': 'u-1',
          'prm': 'key-1',
          'iss': 'test',
          'aud': 'test',
        },
        expired: true,
      );

      final payload = await service.decode(token);

      expect(payload.sub, 'u-1');
    });

    test('decode throws BadTokenError for structurally invalid token',
        () async {
      await expectLater(
        service.decode('not-a-jwt'),
        throwsA(isA<BadTokenError>()),
      );
    });
  });
}
