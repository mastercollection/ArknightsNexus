import 'package:arknight_nexus/core/logging/app_logger.dart';

class NoopAppLogger implements AppLogger {
  @override
  void info(String message) {}

  @override
  void warning(String message, [Object? error, StackTrace? stackTrace]) {}

  @override
  void severe(String message, [Object? error, StackTrace? stackTrace]) {}
}
