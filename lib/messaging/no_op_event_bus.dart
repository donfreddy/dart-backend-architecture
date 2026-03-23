import 'package:dart_backend_architecture/core/logger.dart';
import 'package:dart_backend_architecture/messaging/event_bus.dart';

/// [EventBus] that silently discards all events.
///
/// Used when [NATS_URL] is not configured. This allows the application to
/// start and serve traffic without a NATS broker — events are simply dropped.
/// Deployments that need async event propagation must configure [NATS_URL].
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
