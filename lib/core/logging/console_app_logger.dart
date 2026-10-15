import 'app_logger.dart';

/// [AppLogger] of the web build, which has no log file: lines go to the
/// browser console (`print` is `console.log` there).
class ConsoleAppLogger implements AppLogger {
  const ConsoleAppLogger();

  @override
  void info(String message) => _write('INFO', message);

  @override
  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    _write('WARN', message, error, stackTrace);
  }

  @override
  void severe(String message, [Object? error, StackTrace? stackTrace]) {
    _write('ERROR', message, error, stackTrace);
  }

  void _write(
    String level,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    final buffer = StringBuffer('[$level] $message');
    if (error != null) {
      buffer.write(' | error: $error');
    }
    if (stackTrace != null) {
      buffer.write(' | stack: $stackTrace');
    }
    // ignore: avoid_print
    print(buffer);
  }
}
