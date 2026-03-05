import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_backend_architecture/core/logger.dart';
import 'package:dart_nats/dart_nats.dart';

final _log = AppLogger.get('NatsService');

final class NatsService {
  late final Client _client;
  bool _connected = false;

  NatsService._();

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

    _client = Client();
    await _client.connect(uri);
    _connected = true;

    _log.info('NATS connected -> $natsUrl');
  }

  // ── Publish — fire and forget ─────────────────────────────────

  Future<void> publish(String subject, Map<String, dynamic> payload) async {
    if (!_connected) {
      _log.warning('NATS not connected — dropping event: $subject');
      return;
    }

    try {
      await _client.pubString(subject, jsonEncode(payload));
    } catch (e) {
      // Publishing must never crash the caller
      _log.warning('NATS publish failed [$subject]: $e');
    }
  }

  // ── Subscribe — returns a typed Dart Stream ───────────────────

  Stream<Map<String, dynamic>> subscribe(String subject) {
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

  Future<Map<String, dynamic>?> request(
    String subject,
    Map<String, dynamic> payload, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
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
}
