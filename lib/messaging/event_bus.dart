/// Contract for best-effort event publication.
///
/// Currently backed by [NoOpEventBus] which silently discards all events.
/// This interface exists as an extension point for when async event
/// propagation (e.g. via NATS, RabbitMQ, or Kafka) becomes necessary.
abstract interface class EventBus {
  Future<void> publish(String topic, Map<String, dynamic> payload);
  Future<bool> ping();
  Future<void> close();
}
