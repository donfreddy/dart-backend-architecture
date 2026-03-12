import 'package:dart_backend_architecture/core/middleware/rate_limit_middleware.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

class InMemoryRateStore implements RateLimitStore {
  final Map<String, int> _counts = {};

  @override
  Future<int> increment(String key, {required Duration window}) async {
    final next = (_counts[key] ?? 0) + 1;
    _counts[key] = next;
    return next;
  }
}

void main() {
  test('returns 429 after exceeding max requests', () async {
    final store = InMemoryRateStore();
    final handler = rateLimitMiddleware(
      store,
      maxRequests: 1,
      window: const Duration(minutes: 1),
    )((_) async => Response.ok('ok'));

    final req = Request(
      'GET',
      Uri.parse('http://localhost/test'),
      headers: {'x-forwarded-for': '1.1.1.1'},
    );

    final first = await handler(req);
    final second = await handler(req);

    expect(first.statusCode, 200);
    expect(second.statusCode, 429);
    expect(second.headers['Retry-After'], isNotEmpty);
  });
}
