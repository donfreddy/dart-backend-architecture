import 'package:dart_backend_architecture/messaging/event_bus.dart';
import 'package:dart_backend_architecture/messaging/nats_service.dart';

/// [EventBus] backed by a live NATS connection.
final class NatsEventBus implements EventBus {
  final NatsService _nats;

  const NatsEventBus(this._nats);

  @override
  Future<void> publish(String topic, Map<String, dynamic> payload) =>
      _nats.publish(topic, payload);

  @override
  Future<bool> ping() => _nats.ping();

  @override
  Future<void> close() => _nats.close();
}
