abstract interface class AppLogger {
  void info(String message);

  void warning(String message, [Object? error, StackTrace? stackTrace]);

  void severe(String message, [Object? error, StackTrace? stackTrace]);
}
