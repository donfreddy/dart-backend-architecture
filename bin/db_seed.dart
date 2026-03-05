import 'package:dart_backend_architecture/config.dart';
import 'package:dart_backend_architecture/core/logger.dart';
import 'package:logging/logging.dart';
import 'package:postgres/postgres.dart';

const _vendorApiKey = 'GCMUDiuY5a7WvyUNt9n3QztToSHzK7Uj';

Future<void> main() async {
  AppLogger.configure();
  final log = AppLogger.get('db_seed');

  final config = AppConfig.fromEnv();
  final Pool<dynamic> pool = Pool.withUrl(config.databaseUrl);

  try {
    await pool.runTx((session) async {
      await _seedRoles(session, log);
      await _seedApiKey(session, log);
    });

    log.info('Database seed completed');
  } catch (e, st) {
    log.severe('Database seed failed', e, st);
    rethrow;
  } finally {
    await pool.close();
  }
}

Future<void> _seedRoles(Session session, Logger log) async {
  final roles = ['LEARNER', 'WRITER', 'EDITOR', 'ADMIN'];

  for (final role in roles) {
    await session.execute(
      Sql.named('''
        INSERT INTO roles (code, status, created_at, updated_at)
        VALUES (@code, TRUE, NOW(), NOW())
        ON CONFLICT (code) DO NOTHING
      '''),
      parameters: {'code': role},
    );
  }

  log.info('Roles seeded (idempotent)');
}

Future<void> _seedApiKey(Session session, Logger log) async {
  await session.execute(
    Sql.named('''
      INSERT INTO api_keys (metadata, key, version, status, created_at, updated_at)
      VALUES (@metadata, @key, 1, TRUE, NOW(), NOW())
      ON CONFLICT (key) DO NOTHING
    '''),
    parameters: {
      'metadata': 'To be used by the xyz vendor',
      'key': _vendorApiKey,
    },
  );

  log.info('API key seeded (idempotent)');
}
