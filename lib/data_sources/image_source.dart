/// Image source descriptor logic ported from the Tauri implementation in
/// `src/services/operators.ts`. It maps a logical image request (kind + id)
/// to the cache-relative storage paths and the remote candidate URLs used to
/// download the asset.
library;

const String imageRemoteBaseUrl =
    'https://raw.githubusercontent.com/fexli/ArknightsResource/refs/heads/main';

/// The categories of images cached by the app.
enum CachedImageKind {
  portrait,
  moduleEquip,
  moduleType,
  skillIcon,
  itemIcon,
}

/// A request to resolve a cached image.
class ImageRequest {
  const ImageRequest({
    required this.kind,
    required this.id,
    this.forceRefresh = false,
  });

  final CachedImageKind kind;
  final String id;
  final bool forceRefresh;

  /// Stable cache key matching the Tauri `getImageCacheKey` behavior.
  String get cacheKey => '${kind.name}:${id.trim()}';
}

/// Resolved storage paths and remote candidate URLs for an image.
class ImageDescriptor {
  const ImageDescriptor({
    required this.parentRelativePath,
    required this.relativePath,
    required this.partRelativePath,
    required this.candidateUrls,
  });

  final String parentRelativePath;
  final String relativePath;
  final String partRelativePath;
  final List<String> candidateUrls;
}

final RegExp _allowedImageId = RegExp(r'^[\w.\-\[\]]+$');

/// Validates and trims an image id. Returns `null` when the id is unsafe to use
/// in a file path or URL, matching the Tauri `normalizeImageId` checks.
String? normalizeImageId(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty ||
      normalized.contains('/') ||
      normalized.contains('\\') ||
      normalized.contains('..')) {
    return null;
  }

  if (!_allowedImageId.hasMatch(normalized)) {
    return null;
  }

  return normalized;
}

String _imageFileName(String id) => '$id.png';

/// Builds the descriptor for a [kind]/[id] pair, or `null` when the id is
/// invalid. Mirrors the Tauri `buildImageDescriptor` function.
ImageDescriptor? buildImageDescriptor(CachedImageKind kind, String id) {
  final normalizedId = normalizeImageId(id);
  if (normalizedId == null) {
    return null;
  }

  switch (kind) {
    case CachedImageKind.portrait:
      return ImageDescriptor(
        parentRelativePath: 'images/portraits',
        relativePath: 'images/portraits/${_imageFileName(normalizedId)}',
        partRelativePath:
            'images/portraits/${_imageFileName(normalizedId)}.part',
        candidateUrls: [
          '$imageRemoteBaseUrl/avatar/ASSISTANT/$normalizedId.png',
        ],
      );
    case CachedImageKind.moduleEquip:
      final resolvedId =
          normalizedId.toLowerCase() == 'original' ? 'default' : normalizedId;
      return ImageDescriptor(
        parentRelativePath: 'images/modules/equip',
        relativePath: 'images/modules/equip/${_imageFileName(resolvedId)}',
        partRelativePath:
            'images/modules/equip/${_imageFileName(resolvedId)}.part',
        candidateUrls: ['$imageRemoteBaseUrl/equip/$resolvedId.png'],
      );
    case CachedImageKind.skillIcon:
      return ImageDescriptor(
        parentRelativePath: 'images/skills',
        relativePath: 'images/skills/${_imageFileName(normalizedId)}',
        partRelativePath: 'images/skills/${_imageFileName(normalizedId)}.part',
        candidateUrls: [
          '$imageRemoteBaseUrl/skills/skill_icon_$normalizedId.png',
        ],
      );
    case CachedImageKind.itemIcon:
      return ImageDescriptor(
        parentRelativePath: 'images/items',
        relativePath: 'images/items/${_imageFileName(normalizedId)}',
        partRelativePath: 'images/items/${_imageFileName(normalizedId)}.part',
        candidateUrls: ['$imageRemoteBaseUrl/items/$normalizedId.png'],
      );
    case CachedImageKind.moduleType:
      final uppercaseId = normalizedId.toUpperCase();
      return ImageDescriptor(
        parentRelativePath: 'images/modules/type',
        relativePath: 'images/modules/type/${_imageFileName(normalizedId)}',
        partRelativePath:
            'images/modules/type/${_imageFileName(normalizedId)}.part',
        candidateUrls: uppercaseId == normalizedId
            ? ['$imageRemoteBaseUrl/equipt/$normalizedId.png']
            : [
                '$imageRemoteBaseUrl/equipt/$normalizedId.png',
                '$imageRemoteBaseUrl/equipt/$uppercaseId.png',
              ],
      );
  }
}
