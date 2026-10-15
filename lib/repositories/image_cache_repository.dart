import 'dart:io';

/// File-system boundary for the image cache. All paths are relative to the app
/// cache root (for example `images/portraits/char.png`). Implementations own
/// the persistent file access; the service owns descriptor and network logic.
abstract interface class ImageCacheRepository {
  /// Resolves the absolute [File] handle for a cache-relative path without
  /// performing any IO.
  Future<File> fileFor(String relativePath);

  /// Whether a file exists at the cache-relative path.
  Future<bool> exists(String relativePath);

  /// Ensures the parent directory for the cache-relative path exists.
  Future<void> ensureParent(String parentRelativePath);

  /// Writes bytes to a temporary `.part` file at the cache-relative path.
  Future<void> writePart(String partRelativePath, List<int> bytes);

  /// Atomically moves the `.part` file to its final path and returns it.
  Future<File> promotePart(String partRelativePath, String relativePath);

  /// Removes the file or directory at the cache-relative path if present.
  Future<void> removeIfExists(String relativePath);
}
