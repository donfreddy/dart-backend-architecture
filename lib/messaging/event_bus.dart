/// Contract for best-effort event publication.
///
/// Concrete implementations:
///   - [NatsEventBus] — backed by a live NATS connection.
///   - [NoOpEventBus] — silently discards events (used when NATS is disabled).
///
/// [BlogService] depends on this interface so that NATS is not a required
/// infrastructure dependency for deployments that don't need async events.
abstract interface class EventBus {
  Future<void> publish(String topic, Map<String, dynamic> payload);
  Future<bool> ping();
  Future<void> close();
}
