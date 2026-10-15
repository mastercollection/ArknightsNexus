import 'dart:io';

import '../core/errors/app_failure.dart';
import '../core/http/http_client.dart';
import '../core/logging/app_logger.dart';
import '../data_sources/image_source.dart';
import '../repositories/image_cache_repository.dart';

/// Whether a resolved image is available locally.
enum ImageStatus { ready, missing }

/// Result of resolving an image request.
class ResolvedImage {
  const ResolvedImage.ready(File this.file) : status = ImageStatus.ready;

  const ResolvedImage.missing()
      : status = ImageStatus.missing,
        file = null;

  final ImageStatus status;
  final File? file;

  bool get isReady => status == ImageStatus.ready;
}

abstract interface class ImageCacheService {
  bool isValidImageId(String imageId);

  /// Resolves an image to a local file, downloading and caching it if needed.
  Future<ResolvedImage> resolve(ImageRequest request);

  /// Resolves multiple images concurrently, ignoring individual failures.
  Future<void> prefetch(List<ImageRequest> requests);

  /// Clears the on-disk image cache and in-memory resolution cache.
  Future<void> clearCache();
}

/// Dart port of the Tauri `resolveImageSource` flow. Downloads images to a
/// `.part` file and atomically promotes them, falling back across candidate
/// URLs and caching successful resolutions in memory.
class DartImageCacheService implements ImageCacheService {
  DartImageCacheService({
    required NexusHttpClient httpClient,
    required ImageCacheRepository repository,
    AppLogger? logger,
  })  : _httpClient = httpClient,
        _repository = repository,
        _logger = logger;

  final NexusHttpClient _httpClient;
  final ImageCacheRepository _repository;
  final AppLogger? _logger;

  final Map<String, ResolvedImage> _resolved = {};

  @override
  bool isValidImageId(String imageId) => normalizeImageId(imageId) != null;

  @override
  Future<ResolvedImage> resolve(ImageRequest request) async {
    final descriptor = buildImageDescriptor(request.kind, request.id);
    if (descriptor == null) {
      _logger?.warning(
        '[image-cache] invalid image descriptor '
        '{kind: ${request.kind.name}, id: ${request.id}}',
      );
      return const ResolvedImage.missing();
    }

    final cacheKey = request.cacheKey;
    if (!request.forceRefresh && _resolved.containsKey(cacheKey)) {
      return _resolved[cacheKey]!;
    }

    if (!request.forceRefresh &&
        await _repository.exists(descriptor.relativePath)) {
      final file = await _repository.fileFor(descriptor.relativePath);
      final result = ResolvedImage.ready(file);
      _resolved[cacheKey] = result;
      return result;
    }

    await _repository.ensureParent(descriptor.parentRelativePath);
    await _repository.removeIfExists(descriptor.partRelativePath);

    for (final url in descriptor.candidateUrls) {
      try {
        final bytes = await _httpClient.getBytes(Uri.parse(url));
        await _repository.writePart(descriptor.partRelativePath, bytes);
        final file = await _repository.promotePart(
          descriptor.partRelativePath,
          descriptor.relativePath,
        );
        final result = ResolvedImage.ready(file);
        _resolved[cacheKey] = result;
        return result;
      } on Object catch (error) {
        _logger?.severe(
          '[image-cache] download or rename failed '
          '{kind: ${request.kind.name}, id: ${request.id}, url: $url}',
          error,
        );
        await _repository.removeIfExists(descriptor.partRelativePath);
      }
    }

    _logger?.warning(
      '[image-cache] all image candidates failed '
      '{kind: ${request.kind.name}, id: ${request.id}}',
    );
    return const ResolvedImage.missing();
  }

  @override
  Future<void> prefetch(List<ImageRequest> requests) async {
    if (requests.isEmpty) {
      return;
    }

    await Future.wait(
      requests.map((request) async {
        try {
          await resolve(request);
        } on AppFailure {
          // Prefetch is best-effort; individual failures are already logged.
        }
      }),
    );
  }

  @override
  Future<void> clearCache() async {
    await _repository.removeIfExists('images');
    _resolved.clear();
  }
}
