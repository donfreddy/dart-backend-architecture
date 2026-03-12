import 'package:dart_backend_architecture/routes/health_handler.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  test('healthz returns live status', () async {
    final res = await healthzHandler(
      Request('GET', Uri.parse('http://localhost/healthz')),
    );
    expect(res.statusCode, 200);
    expect(await res.readAsString(), contains('"status":"10000"'));
  });

  test('readyz returns 200 when all probes ok', () async {
    final res = await readyzHandler(
      dbCheck: () async => true,
      cacheCheck: () async => true,
      natsCheck: () async => true,
    );

    expect(res.statusCode, 200);
    expect(await res.readAsString(), contains('"ready"'));
  });

  test('readyz returns 503 when a probe fails', () async {
    final res = await readyzHandler(
      dbCheck: () async => true,
      cacheCheck: () async => false,
      natsCheck: () async => true,
    );

    expect(res.statusCode, 503);
    expect(await res.readAsString(), contains('"degraded"'));
  });
}
