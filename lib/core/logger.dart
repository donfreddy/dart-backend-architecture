import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

class AppLogger {
  AppLogger._();

  static bool _configured = false;

  static void configure({bool verbose = false}) {
    if (_configured) return;
    _configured = true;

    Logger.root.level = verbose ? Level.ALL : Level.INFO;
    Logger.root.onRecord.listen(_handleRecord);
  }

  static void _handleRecord(LogRecord record) {
    final log = <String, dynamic>{
      'ts': record.time.toIso8601String(),
      'level': record.level.name,
      'logger': record.loggerName,
      'message': record.message,
    };

    if (record.error != null) {
      log['error'] = record.error.toString();
    }

    if (record.stackTrace != null) {
      log['stack'] = record.stackTrace.toString();
    }

    // Structured output: stderr for errors, stdout for the rest
    final line = jsonEncode(log);
    if (record.level >= Level.SEVERE) {
      stderr.writeln(line);
    } else {
      stdout.writeln(line);
    }
  }

  static Logger get root => Logger.root;

  static Logger get(String name) => Logger(name);
}
