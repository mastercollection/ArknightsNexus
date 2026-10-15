import 'dart:io';

import 'package:path/path.dart' as p;

import '../storage/app_directories.dart';
import 'app_logger.dart';

/// [AppLogger] that appends timestamped lines to a rolling log file under the
/// app log directory. Writes are serialized and best-effort: IO failures are
/// swallowed so logging never crashes the app (and so widget tests that lack
/// platform plugins stay silent).
class FileAppLogger implements AppLogger {
  FileAppLogger(this._directories);

  static const String logFileName = 'app.log';

  final AppDirectories _directories;
  Future<void> _writeQueue = Future.value();

  /// Resolves the absolute path of the active log file.
  Future<String> logFilePath() async {
    final root = await _directories.logRoot();
    return p.join(root.path, logFileName);
  }

  @override
  void info(String message) => _enqueue('INFO', message);

  @override
  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    _enqueue('WARN', _compose(message, error, stackTrace));
  }

  @override
  void severe(String message, [Object? error, StackTrace? stackTrace]) {
    _enqueue('ERROR', _compose(message, error, stackTrace));
  }

  String _compose(String message, Object? error, StackTrace? stackTrace) {
    final buffer = StringBuffer(message);
    if (error != null) {
      buffer.write(' | error: $error');
    }
    if (stackTrace != null) {
      buffer.write(' | stack: $stackTrace');
    }
    return buffer.toString();
  }

  void _enqueue(String level, String message) {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final line = '$timestamp [$level] $message\n';
    _writeQueue = _writeQueue.then((_) => _append(line)).catchError((_) {});
  }

  Future<void> _append(String line) async {
    final root = await _directories.logRoot();
    final file = File(p.join(root.path, logFileName));
    await file.writeAsString(line, mode: FileMode.append, flush: true);
  }
}
