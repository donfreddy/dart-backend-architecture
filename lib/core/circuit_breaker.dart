import 'dart:async';

import 'package:dart_backend_architecture/core/logger.dart';

enum _State { closed, open, halfOpen }

/// Simple circuit breaker with closed → open → half-open → closed cycle.
///
/// When failures reach [failureThreshold] the circuit opens and
/// all subsequent calls throw [CircuitBreakerOpenException] for
/// [resetTimeout].  After the timeout one test call is let through
/// (half‑open); if it succeeds the circuit closes again.
final class CircuitBreaker {
  final String name;
  final int failureThreshold;
  final Duration resetTimeout;

  final _log = AppLogger.get('CircuitBreaker');

  _State _state = _State.closed;
  int _failureCount = 0;
  DateTime? _openedAt;
  bool _halfOpenTestInProgress = false;

  CircuitBreaker({
    required this.name,
    this.failureThreshold = 5,
    this.resetTimeout = const Duration(seconds: 10),
  });

  CircuitBreakerState get state => switch (_state) {
        _State.closed => CircuitBreakerState.closed,
        _State.open => CircuitBreakerState.open,
        _State.halfOpen => CircuitBreakerState.halfOpen,
      };

  int get failureCount => _failureCount;

  Future<T> execute<T>(Future<T> Function() fn) async {
    if (_state == _State.open) {
      if (_openedAt != null &&
          DateTime.now().difference(_openedAt!) >= resetTimeout) {
        _state = _State.halfOpen;
        _halfOpenTestInProgress = false;
      } else {
        throw CircuitBreakerOpenException._(name);
      }
    }

    if (_state == _State.halfOpen) {
      if (_halfOpenTestInProgress) {
        throw CircuitBreakerOpenException._(name);
      }
      _halfOpenTestInProgress = true;
    }

    try {
      final result = await fn();
      if (_state == _State.halfOpen) {
        _state = _State.closed;
        _failureCount = 0;
        _halfOpenTestInProgress = false;
        _openedAt = null;
        _log.info('Circuit [$name] closed — recovered');
      }
      return result;
    } catch (e) {
      _failureCount++;
      _log.warning('Circuit [$name] failure #$_failureCount: $e');
      if (_failureCount >= failureThreshold || _state == _State.halfOpen) {
        _state = _State.open;
        _openedAt = DateTime.now();
        _halfOpenTestInProgress = false;
        _log.warning(
          'Circuit [$name] OPEN — short-circuiting for $resetTimeout',
        );
      }
      rethrow;
    }
  }

  void reset() {
    _state = _State.closed;
    _failureCount = 0;
    _openedAt = null;
    _halfOpenTestInProgress = false;
  }
}

enum CircuitBreakerState { closed, open, halfOpen }

class CircuitBreakerOpenException implements Exception {
  final String breakerName;
  CircuitBreakerOpenException._(this.breakerName);

  @override
  String toString() => 'CircuitBreaker[$breakerName] is OPEN';
}
