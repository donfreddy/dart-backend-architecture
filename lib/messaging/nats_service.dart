import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';

import 'package:dart_backend_architecture/core/logger.dart';
import 'package:dart_nats/dart_nats.dart';

final _log = AppLogger.get('NatsService');

/// Thin NATS client with auto-reconnect/backoff and best-effort publish.
/// Intended to be injected as a singleton per process.
final class NatsService {
  late Client _client;
  bool _connected = false;
  late Uri _uri;
  Completer<void>? _reconnectCompleter;

  NatsService._();

  /// Connect and return a ready-to-use service.
  static Future<NatsService> connect(String natsUrl) async {
    final service = NatsService._();
    await service._init(natsUrl);
    return service;
  }

  Future<void> _init(String natsUrl) async {
    final uri = Uri.parse(natsUrl);
    if (uri.host.isEmpty) {
      throw ArgumentError.value(
        natsUrl,
        'natsUrl',
        'Invalid NATS URL: host is required',
      );
    }

    _uri = uri;
    await _connectWithRetry();
  }

  // ── Publish — fire and forget ─────────────────────────────────

  /// Publish a JSON payload. Retries once after reconnect on failure.
  Future<void> publish(String subject, Map<String, dynamic> payload) async {
    await _ensureConnected();

    try {
      await _client.pubString(subject, jsonEncode(payload));
    } catch (e) {
      _connected = false;
      _log.warning('NATS publish failed [$subject], will retry after reconnect: $e');
      await _ensureConnected();
      try {
        await _client.pubString(subject, jsonEncode(payload));
      } catch (e) {
        _log.warning('NATS publish failed after retry [$subject]: $e');
      }
    }
  }

  // ── Subscribe — returns a typed Dart Stream ───────────────────

  /// Subscribe to a subject and get a stream of decoded JSON maps.
  Future<Stream<Map<String, dynamic>>> subscribe(String subject) async {
    await _ensureConnected();
    if (!_connected) {
      _log.warning('NATS not connected — subscribe ignored: $subject');
      return const Stream<Map<String, dynamic>>.empty();
    }

    final sub = _client.sub<dynamic>(subject);

    return sub.stream.map((msg) {
      try {
        final decoded = jsonDecode(msg.string);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return decoded.cast<String, dynamic>();
        return <String, dynamic>{};
      } catch (e) {
        _log.warning('Failed to decode NATS message on $subject: $e');
        return <String, dynamic>{};
      }
    }).where((msg) => msg.isNotEmpty);
  }

  // ── Request / Reply ──────────────────────────────────────────

  /// Send a request and await a JSON map response. Returns `null` on timeout or failure.
  Future<Map<String, dynamic>?> request(
    String subject,
    Map<String, dynamic> payload, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    await _ensureConnected();
    if (!_connected) return null;

    try {
      final response = await _client
          .request<dynamic>(
            subject,
            Uint8List.fromList(utf8.encode(jsonEncode(payload))),
          )
          .timeout(timeout);

      final decoded = jsonDecode(response.string);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
      return null;
    } catch (e) {
      _log.warning('NATS request failed [$subject]: $e');
      return null;
    }
  }

  Future<void> close() async {
    if (!_connected) return;
    await _client.close();
    _connected = false;
    _log.info('NATS connection closed');
  }

  Future<bool> ping({Duration timeout = const Duration(seconds: 2)}) async {
    try {
      await _ensureConnected();
      return _connected;
    } catch (e) {
      _log.warning('NATS ping failed: $e');
      return false;
    }
  }

  // ── Internal helpers ──────────────────────────────────────────

  Future<void> _ensureConnected() async {
    if (_connected) return;
    await _reconnect();
  }

  Future<void> _reconnect() async {
    if (_reconnectCompleter != null) {
      return _reconnectCompleter!.future;
    }
    final completer = _reconnectCompleter = Completer<void>();

    try {
      await _connectWithRetry();
      completer.complete();
    } catch (e) {
      completer.completeError(e);
    } finally {
      _reconnectCompleter = null;
    }
  }

  Future<void> _connectWithRetry() async {
    var backoff = const Duration(milliseconds: 200);

    for (var attempt = 1; attempt <= 5; attempt++) {
      try {
        _client = Client();
        await _client.connect(_uri);
        _connected = true;
        _log.info('NATS connected -> ${_uri.toString()}');
        return;
      } catch (e) {
        _connected = false;
        _log.warning('NATS connect attempt $attempt failed: $e');
        if (attempt == 5) rethrow;
        await Future<void>.delayed(backoff);
        backoff *= 2;
      }
    }
  }
}
