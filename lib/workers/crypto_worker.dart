import 'dart:isolate';
import 'dart:async';

import 'package:bcrypt/bcrypt.dart';
import 'package:dart_backend_architecture/core/logger.dart';

final _log = AppLogger.get('CryptoWorker');

// ── Messages ─────────────────────────────────────────────────────────────────

sealed class _CryptoMessage {
  const _CryptoMessage();
}

final class _HashRequest extends _CryptoMessage {
  final String plaintext;
  final SendPort replyPort;
  const _HashRequest(this.plaintext, this.replyPort);
}

final class _VerifyRequest extends _CryptoMessage {
  final String plaintext;
  final String hash;
  final SendPort replyPort;
  const _VerifyRequest(this.plaintext, this.hash, this.replyPort);
}

final class _FakeHashRequest extends _CryptoMessage {
  final SendPort replyPort;
  const _FakeHashRequest(this.replyPort);
}

final class _ShutdownRequest extends _CryptoMessage {
  const _ShutdownRequest();
}

// ── Worker ───────────────────────────────────────────────────────────────────
class CryptoWorker {
  final SendPort _sendPort;
  final Isolate _isolate;

  CryptoWorker._(this._sendPort, this._isolate);

  static Future<CryptoWorker> spawn() async {
    final receivePort = ReceivePort();

    final isolate = await Isolate.spawn(
      _workerEntryPoint,
      receivePort.sendPort,
      debugName: 'crypto-worker',
    );

    // Wait for the worker to send back its own SendPort
    final sendPort = await receivePort.first as SendPort;
    receivePort.close();

    _log.info('CryptoWorker isolate spawned');
    return CryptoWorker._(sendPort, isolate);
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<String> hashPassword(String plaintext) async {
    final reply = ReceivePort();
    _sendPort.send(_HashRequest(plaintext, reply.sendPort));
    try {
      final result = await reply.first.timeout(const Duration(seconds: 5));

      if (result is String && !result.startsWith('HASH_ERROR:')) return result;
      throw StateError('hashPassword failed: $result');
    } finally {
      reply.close();
    }
  }

  Future<bool> verifyPassword(String plaintext, String hash) async {
    final reply = ReceivePort();
    _sendPort.send(_VerifyRequest(plaintext, hash, reply.sendPort));
    try {
      final result = await reply.first.timeout(const Duration(seconds: 5));

      if (result is bool) return result;
      throw StateError('verifyPassword failed: $result');
    } finally {
      reply.close();
    }
  }

  // Constant-time dummy hash:  prevents user enumeration via timing attacks
  Future<void> fakeHash() async {
    final reply = ReceivePort();
    _sendPort.send(_FakeHashRequest(reply.sendPort));
    await reply.first;
    reply.close();
  }

  Future<void> dispose() async {
    _sendPort.send(const _ShutdownRequest());
    _isolate.kill(priority: Isolate.beforeNextEvent);
    _log.info('CryptoWorker isolate disposed');
  }
}

// ── Worker entry point (runs inside the Isolate) ─────────────────────────────

void _workerEntryPoint(SendPort callerSendPort) {
  final receivePort = ReceivePort();

  // Send our SendPort back so the main isolate can reach us
  callerSendPort.send(receivePort.sendPort);

  receivePort.listen((dynamic message) {
    switch (message) {
      case _HashRequest(:final plaintext, :final replyPort):
        try {
          final hash = _bcryptHash(plaintext);
          replyPort.send(hash);
        } catch (e) {
          replyPort.send('HASH_ERROR:$e');
        }

      case _VerifyRequest(:final plaintext, :final hash, :final replyPort):
        try {
          final valid = _bcryptVerify(plaintext, hash);
          replyPort.send(valid);
        } catch (e) {
          replyPort.send(false);
        }

      case _FakeHashRequest(:final replyPort):
        // Run a real hash to ensure constant timing
        _bcryptHash('__fake_password_dba__');
        replyPort.send(true);

      case _ShutdownRequest():
        receivePort.close();
    }
  });
}

// ── BCrypt implementation ────────────────────────────────────────────────────

String _bcryptHash(String plaintext) {
  return BCrypt.hashpw(
    plaintext,
    BCrypt.gensalt(logRounds: 12),
  );
}

bool _bcryptVerify(String plaintext, String hash) {
  return BCrypt.checkpw(plaintext, hash);
}
