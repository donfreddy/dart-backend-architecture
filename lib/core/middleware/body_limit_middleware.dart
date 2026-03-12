import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';

class _BodyTooLarge implements Exception {}

Middleware bodyLimitMiddleware({int maxBytes = 1024 * 1024}) {
  return (Handler inner) {
    return (Request request) async {
      final contentLength = int.tryParse(request.headers['content-length'] ?? '');
      if (contentLength != null && contentLength > maxBytes) {
        return _tooLarge();
      }

      var total = 0;
      final limitedStream = request.read().transform(
            StreamTransformer.fromHandlers(
              handleData: (chunk, sink) {
                total += chunk.length;
                if (total > maxBytes) {
                  sink.addError(_BodyTooLarge());
                  return;
                }
                sink.add(chunk);
              },
            ),
          );

      try {
        final limitedRequest = request.change(body: limitedStream);
        return await inner(limitedRequest);
      } on _BodyTooLarge {
        return _tooLarge();
      }
    };
  };
}

Response _tooLarge() => Response(
      413,
      body: jsonEncode({
        'status': '10001', // keep envelope code consistent with failure
        'message': 'Payload too large',
      }),
      headers: {'content-type': 'application/json'},
    );
