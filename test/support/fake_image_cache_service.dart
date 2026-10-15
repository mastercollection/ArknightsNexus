import 'package:arknight_nexus/data_sources/image_source.dart';
import 'package:arknight_nexus/services/image_cache_service.dart';

/// No-op [ImageCacheService] for widget tests. It never touches the network or
/// file system and always reports images as missing so widgets fall back to
/// their placeholders.
class FakeImageCacheService implements ImageCacheService {
  final requestedIds = <String>[];
  int clearCacheCalls = 0;

  @override
  bool isValidImageId(String imageId) => normalizeImageId(imageId) != null;

  @override
  Future<ResolvedImage> resolve(ImageRequest request) async {
    requestedIds.add(request.id);
    return const ResolvedImage.missing();
  }

  @override
  Future<void> prefetch(List<ImageRequest> requests) async {}

  @override
  Future<void> clearCache() async {
    clearCacheCalls += 1;
  }
}
