sealed class AppFailure {
  const AppFailure(this.message);

  final String message;

  /// Shown verbatim in error states, like the Tauri `AppError` strings.
  @override
  String toString() => message;
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message);
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
