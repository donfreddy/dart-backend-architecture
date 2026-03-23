/// Static metadata about this service.
///
/// Single source of truth for the service name and version used across
/// OpenTelemetry instrumentation, JWT issuer claims, and any other
/// component that needs to identify this application.
abstract final class AppInfo {
  static const String name = 'dart-backend-architecture';
  static const String version = '1.0.0';
  static const String namespace = 'dba';
}
