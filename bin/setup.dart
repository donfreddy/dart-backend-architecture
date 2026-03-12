import 'dart:io';

import 'package:dart_backend_architecture/core/logger.dart';
import 'package:logging/logging.dart';

const _oldName = 'dart_backend_architecture';
const _oldDescription = 'A production-ready, clean architecture blueprint '
    'for building scalable backend servers with Dart.';

Future<void> main() async {
  AppLogger.configure();
  final log = AppLogger.get('setup');
  _printBanner(log);

  // ── 1. Project name ────────────────────────────────────────
  final projectName = _promptProjectName();

  // ── 2. Project description ─────────────────────────────────
  stdout.write('\nProject description (press Enter to keep default):\n> ');
  final inputDesc = stdin.readLineSync()?.trim() ?? '';
  final projectDescription = inputDesc.isEmpty ? _oldDescription : inputDesc;

  log.info('\n⚙️  Configuring project: $_oldName → $projectName\n');

  // ── 3. Replace package name in source files ─────────────────
  await _replaceInFiles(projectName, projectDescription, log);

  // ── 4. Generate RSA key pair ───────────────────────────────
  await _generateKeys(log);

  // ── 5. Create .env from .env.example ──────────────────────
  await _createEnvFile(log);

  // ── 6. dart pub get ────────────────────────────────────────
  await _pubGet(log);

  _printSuccess(projectName, log);
}

// ── Prompt ─────────────────────────────────────────────────────

String _promptProjectName() {
  while (true) {
    stdout.write('Enter your project name (snake_case, e.g. my_api):\n> ');
    final input = stdin.readLineSync()?.trim() ?? '';

    if (input.isEmpty) {
      _error('Project name cannot be empty.');
      continue;
    }

    // Dart package name rules: lowercase, underscores, no leading digits
    final valid = RegExp(r'^[a-z][a-z0-9_]*$');
    if (!valid.hasMatch(input)) {
      _error(
          'Invalid name. Use lowercase letters, digits and underscores only (e.g. my_api).');
      continue;
    }

    if (input == _oldName) {
      _error('Choose a different name from the template.');
      continue;
    }

    return input;
  }
}

// ── File replacement ───────────────────────────────────────────

Future<void> _replaceInFiles(
    String newName, String newDescription, Logger log) async {
  final root = Directory.current;
  var count = 0;

  await for (final entity in root.list(recursive: true)) {
    if (entity is! File) continue;
    if (!_isEligible(entity.path)) continue;

    try {
      final original = await entity.readAsString();
      var updated = original
          .replaceAll(_oldName, newName)
          .replaceAll(_oldDescription, newDescription);

      if (updated != original) {
        await entity.writeAsString(updated);
        log.info('  ✓ ${_relativePath(entity.path)}');
        count++;
      }
    } catch (_) {
      // Skip binary or unreadable files silently
    }
  }

  log.info('\n  $count file(s) updated.\n');
}

bool _isEligible(String path) {
  const excluded = ['.git/', '.dart_tool/', 'bin/setup.dart'];
  if (excluded.any(path.contains)) return false;

  const extensions = ['.dart', '.yaml', '.yml', '.md', '.env.example', '.txt'];
  return extensions.any(path.endsWith);
}

// ── RSA key generation ─────────────────────────────────────────

Future<void> _generateKeys(Logger log) async {
  log.info('🔑 Generating RSA key pair...');

  final keysDir = Directory('keys');
  if (!keysDir.existsSync()) keysDir.createSync();

  final privateKey = File('keys/private.pem');
  final publicKey = File('keys/public.pem');

  if (privateKey.existsSync() && publicKey.existsSync()) {
    log.info(
        '  ⚠️  keys/private.pem and keys/public.pem already exist — skipping.\n');
    return;
  }

  // Check openssl is available
  final which = await Process.run('which', ['openssl']);
  if (which.exitCode != 0) {
    log.info('  ⚠️  openssl not found. Generate keys manually:\n'
        '      openssl genrsa -out keys/private.pem 2048\n'
        '      openssl rsa -in keys/private.pem -pubout -out keys/public.pem\n');
    return;
  }

  final genKey = await Process.run('openssl', [
    'genrsa',
    '-out',
    'keys/private.pem',
    '2048',
  ]);

  if (genKey.exitCode != 0) {
    _error('Failed to generate private key:\n${genKey.stderr}');
    return;
  }

  final extractPub = await Process.run('openssl', [
    'rsa',
    '-in',
    'keys/private.pem',
    '-pubout',
    '-out',
    'keys/public.pem',
  ]);

  if (extractPub.exitCode != 0) {
    _error('Failed to extract public key:\n${extractPub.stderr}');
    return;
  }

  log.info('  ✓ keys/private.pem');
  log.info('  ✓ keys/public.pem\n');
}

// ── .env creation ──────────────────────────────────────────────

Future<void> _createEnvFile(Logger log) async {
  log.info('📄 Creating .env file...');

  final envFile = File('.env');
  if (envFile.existsSync()) {
    log.info('  ⚠️  .env already exists — skipping.\n');
    return;
  }

  final example = File('.env.example');
  if (!example.existsSync()) {
    _error('.env.example not found — cannot create .env.');
    return;
  }

  await example.copy('.env');
  log.info('  ✓ .env created from .env.example\n');
}

// ── dart pub get ───────────────────────────────────────────────

Future<void> _pubGet(Logger log) async {
  log.info('📦 Installing dependencies...');

  final result = await Process.run(
    'dart',
    ['pub', 'get'],
    runInShell: true,
  ).timeout(
    const Duration(seconds: 60),
    onTimeout: () {
      _error(
          'dart pub get timed out after 60s. Check your internet connection.');
      exit(1);
    },
  );

  if (result.exitCode != 0) {
    _error('dart pub get failed:\n${result.stderr}');
    exit(1);
  }

  log.info('  ✓ Dependencies installed\n');
}

// ── Helpers ────────────────────────────────────────────────────

void _printBanner(Logger log) {
  log.info('''
╔═══════════════════════════════════════════════╗
║       Dart Backend Architecture — Setup       ║
╚═══════════════════════════════════════════════╝
''');
}

void _printSuccess(String projectName, Logger log) {
  log.info('''
╔═══════════════════════════════════════════════╗
║              Setup complete ✓                 ║
╚═══════════════════════════════════════════════╝

  Project : $projectName
  
  Next steps:

  With Docker (recommended):
    docker-compose up --build

  Locally:
    dbmate up
    dart run bin/server.dart

  Run tests:
    dart test test/unit/
''');
}

void _error(String message) => stderr.writeln('  ✗ $message');

String _relativePath(String absolute) =>
    absolute.replaceFirst('${Directory.current.path}/', '');
