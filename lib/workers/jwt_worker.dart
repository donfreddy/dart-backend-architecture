import 'dart:async';
import 'dart:isolate';

import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/core/logger.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

final _log = AppLogger.get('JwtWorker');

// ── Messages ─────────────────────────────────────────────────────────────────

sealed class _JwtMessage {
  const _JwtMessage();
}

final class _ValidateRequest extends _JwtMessage {
  final String token;
  final SendPort replyPort;
  const _ValidateRequest(this.token, this.replyPort);
}

final class _DecodeRequest extends _JwtMessage {
  final String token;
  final SendPort replyPort;
  const _DecodeRequest(this.token, this.replyPort);
}

final class _ShutdownRequest extends _JwtMessage {
  const _ShutdownRequest();
}

// Response protocol (worker → main isolate):
//   success  → Map<String, dynamic>   (raw JWT payload)
//   expired  → 'EXPIRED'
//   invalid  → 'INVALID'
//   error    → 'ERROR:<message>'

// ── Worker ────────────────────────────────────────────────────────────────────

/// Offloads RSA JWT verification to a dedicated [Isolate].
///
/// RSA signature verification is CPU-intensive (~0.5–2 ms per call). At high
/// request rates this would block the HTTP isolate's event loop. Delegating
/// to [JwtWorker] keeps I/O handling uncontested.
class JwtWorker {
  final SendPort _sendPort;
  final Isolate _isolate;

  JwtWorker._(this._sendPort, this._isolate);

  static Future<JwtWorker> spawn(String publicKeyPem) async {
    final ready = ReceivePort();

    final isolate = await Isolate.spawn(
      _workerEntry,
      (ready.sendPort, publicKeyPem),
      debugName: 'jwt-worker',
    );

    final sendPort = await ready.first as SendPort;
    ready.close();

    _log.info('JwtWorker isolate spawned');
    return JwtWorker._(sendPort, isolate);
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Verify [token] signature **and** expiry.
  /// Throws [TokenExpiredError] or [BadTokenError] on failure.
  Future<Map<String, dynamic>> validate(String token) async {
    final reply = ReceivePort();
    _sendPort.send(_ValidateRequest(token, reply.sendPort));
    try {
      final result = await reply.first.timeout(const Duration(seconds: 5));
      return _unwrap(result);
    } finally {
      reply.close();
    }
  }

  /// Decode [token] without checking expiry.
  /// Throws [BadTokenError] on structural failures.
  Future<Map<String, dynamic>> decode(String token) async {
    final reply = ReceivePort();
    _sendPort.send(_DecodeRequest(token, reply.sendPort));
    try {
      final result = await reply.first.timeout(const Duration(seconds: 5));
      return _unwrap(result);
    } finally {
      reply.close();
    }
  }

  Future<void> dispose() async {
    _sendPort.send(const _ShutdownRequest());
    _isolate.kill(priority: Isolate.beforeNextEvent);
    _log.info('JwtWorker isolate disposed');
  }

  // ── Response decoding ────────────────────────────────────────────────────────

  static Map<String, dynamic> _unwrap(dynamic result) {
    if (result is Map<String, dynamic>) return result;
    if (result == 'EXPIRED') throw const TokenExpiredError();
    // 'INVALID' or 'ERROR:...'
    throw const BadTokenError();
  }
}

// ── Worker entry point (runs inside the Isolate) ──────────────────────────────

void _workerEntry((SendPort, String) params) {
  final (callerPort, publicKeyPem) = params;
  final receivePort = ReceivePort();
  callerPort.send(receivePort.sendPort);

  final publicKey = RSAPublicKey(publicKeyPem);

  receivePort.listen((dynamic msg) {
    switch (msg) {
      case _ValidateRequest(:final token, :final replyPort):
        replyPort.send(_verify(token, publicKey, checkExpiry: true));

      case _DecodeRequest(:final token, :final replyPort):
        replyPort.send(_verify(token, publicKey, checkExpiry: false));

      case _ShutdownRequest():
        receivePort.close();
    }
  });
}

dynamic _verify(String token, RSAPublicKey key, {required bool checkExpiry}) {
  try {
    final jwt = JWT.verify(token, key, checkExpiresIn: checkExpiry);
    return jwt.payload as Map<String, dynamic>;
  } on JWTExpiredException {
    return 'EXPIRED';
  } on JWTException {
    return 'INVALID';
  } catch (e) {
    return 'ERROR:$e';
  }
}
