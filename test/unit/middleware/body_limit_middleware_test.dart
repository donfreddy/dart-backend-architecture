import 'dart:convert';

import 'package:dart_backend_architecture/core/middleware/body_limit_middleware.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  Future<Response> handler(Request _) async => Response.ok('ok');
  final mw = bodyLimitMiddleware(maxBytes: 5);

  test('blocks when content-length exceeds limit', () async {
    final limited = mw(handler);
    final req = Request(
      'POST',
      Uri.parse('http://localhost/'),
      headers: {'content-length': '10'},
      body: '0123456789',
    );

    final res = await limited(req);

    expect(res.statusCode, 413);
  });

  test('streams body and blocks when crossing limit', () async {
    final limited = mw(handler);
    final req = Request(
      'POST',
      Uri.parse('http://localhost/'),
      body: utf8.encode('123456'), // 6 bytes > 5
    );

    final res = await limited(req);

    expect(res.statusCode, 413);
  });

  test('allows payload under limit', () async {
    final limited = mw(handler);
    final req = Request(
      'POST',
      Uri.parse('http://localhost/'),
      body: '1234',
    );

    final res = await limited(req);

    expect(res.statusCode, 200);
    expect(await res.readAsString(), 'ok');
  });
}
