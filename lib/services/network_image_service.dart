import '../core/http/http_client.dart';
import '../core/logging/app_logger.dart';
import '../data_sources/image_source.dart';
import 'image_cache_service.dart';

/// [ImageCacheService] for the web build: downloads each image straight from
/// its remote URL (raw.githubusercontent.com allows cross-origin reads) and
/// keeps the bytes in memory for the session. The browser's HTTP cache makes
/// later visits cheap; nothing is written to storage.
///
/// Like the file cache it tries the descriptor's candidate URLs in order and
/// reports [ResolvedImage.missing] when none answers, so widgets show their
/// fallback instead of a broken image.
class NetworkImageService implements ImageCacheService {
  NetworkImageService({
    required NexusHttpClient httpClient,
    AppLogger? logger,
  })  : _httpClient = httpClient,
        _logger = logger;

  final NexusHttpClient _httpClient;
  final AppLogger? _logger;

  /// Completed and in-flight resolutions; concurrent requests share one
  /// download.
  final Map<String, Future<ResolvedImage>> _resolved = {};

  @override
  Future<ResolvedImage> resolve(ImageRequest request) {
    final cacheKey = request.cacheKey;
    final cached = _resolved[cacheKey];
    if (!request.forceRefresh && cached != null) {
      return cached;
    }
    final loading = _download(request);
    _resolved[cacheKey] = loading;
    loading.then((result) {
      // A missing image is retried by the next request.
      if (!result.isReady && identical(_resolved[cacheKey], loading)) {
        _resolved.remove(cacheKey);
      }
    });
    return loading;
  }

  Future<ResolvedImage> _download(ImageRequest request) async {
    final descriptor = buildImageDescriptor(request.kind, request.id);
    if (descriptor == null) {
      _logger?.warning(
        '[image-cache] invalid image descriptor '
        '{kind: ${request.kind.name}, id: ${request.id}}',
      );
      return const ResolvedImage.missing();
    }
    for (final url in descriptor.candidateUrls) {
      try {
        return ResolvedImage.bytes(await _httpClient.getBytes(Uri.parse(url)));
      } on Object catch (error) {
        _logger?.warning(
          '[image-cache] download failed '
          '{kind: ${request.kind.name}, id: ${request.id}, url: $url}',
          error,
        );
      }
    }
    return const ResolvedImage.missing();
  }

  @override
  Future<void> prefetch(List<ImageRequest> requests) async {
    await Future.wait(requests.map(resolve));
  }
}
