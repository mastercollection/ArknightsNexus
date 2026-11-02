sealed class AppFailure {
  const AppFailure(this.message);

  final String message;

  /// Shown verbatim in error states, like the Tauri `AppError` strings.
  @override
  String toString() => message;
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message, {this.statusCode});

  /// The HTTP status of a response that was not a success; null when no
  /// response came.
  final int? statusCode;
}

/// A stage has no level file: a story-only stage, or one the upstream
/// repository does not carry.
final class MissingLevelFailure extends AppFailure {
  const MissingLevelFailure(super.message);
}

final class CacheFailure extends AppFailure {
  const CacheFailure(super.message);
}

final class MissingCacheFailure extends AppFailure {
  const MissingCacheFailure(super.message);
}

final class ParseFailure extends AppFailure {
  const ParseFailure(super.message, {this.source});

  final String? source;
}

final class UnsupportedRegionFailure extends AppFailure {
  const UnsupportedRegionFailure(super.message);
}

final class InvalidInputFailure extends AppFailure {
  const InvalidInputFailure(super.message);
}

final class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message);
}

/// A game account server answered but refused the request (wrong code,
/// expired session, maintenance, ...).
final class AccountFailure extends AppFailure {
  const AccountFailure(super.message, {this.code});

  /// The server's own result code, when it sent one.
  final Object? code;
}
