import 'dart:io';

import 'package:zema/zema.dart';

final class AppConfig {
  final int port;
  final String databaseUrl;
  final String redisUrl;
  final String natsUrl;
  final String jwtPrivateKeyPath;
  final String jwtPublicKeyPath;
  final String environment;

  const AppConfig._({
    required this.port,
    required this.databaseUrl,
    required this.redisUrl,
    required this.natsUrl,
    required this.jwtPrivateKeyPath,
    required this.jwtPublicKeyPath,
    required this.environment,
  });

  factory AppConfig.fromEnv() {
    final schema = z.object({
      'PORT': z.coerce().integer(min: 1, max: 65535).withDefault(8080),
      'DATABASE_URL': z.string().url(),
      'REDIS_URL': z.string().min(1),
      'NATS_URL': z.string().min(1),
      'JWT_PRIVATE_KEY_PATH': z.string().min(1),
      'JWT_PUBLIC_KEY_PATH': z.string().min(1),
      //'ENVIRONMENT': z.enum(['development', 'production', 'staging']).withDefault('development'),
      'ENVIRONMENT': z.string().min(1).withDefault('development'),
    });

    final result = schema.safeParse(Platform.environment);
    if (result.isFailure) {
      throw Exception('Invalid environment config: \n${result.errors.format()}');
    }

    final env = result.value;

    return AppConfig._(
      port: env['PORT'] as int,
      databaseUrl: env['DATABASE_URL'] as String,
      redisUrl: env['REDIS_URL'] as String,
      natsUrl: env['NATS_URL'] as String,
      jwtPrivateKeyPath: env['JWT_PRIVATE_KEY_PATH'] as String,
      jwtPublicKeyPath: env['JWT_PUBLIC_KEY_PATH'] as String,
      environment: env['ENVIRONMENT'] as String,
    );
  }
}
