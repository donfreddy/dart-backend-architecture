import 'package:dart_backend_architecture/core/logger.dart';
import 'package:dart_backend_architecture/messaging/event_bus.dart';

/// [EventBus] that silently discards all events.
///
/// This is the only active implementation. Replace with a real transport
/// (e.g. NATS, RabbitMQ, Kafka) when async event consumers exist.
final class NoOpEventBus implements EventBus {
  static final _log = AppLogger.get('NoOpEventBus');

  const NoOpEventBus();

  @override
  Future<void> publish(String topic, Map<String, dynamic> payload) async {
    _log.info('NoOpEventBus: dropped event [$topic]');
  }

  @override
  Future<bool> ping() async => true;

  @override
  Future<void> close() async {}
}
