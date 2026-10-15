import 'package:flutter/widgets.dart';

import '../services/image_cache_service.dart';
import 'file_image_provider_web.dart'
    if (dart.library.io) 'file_image_provider_io.dart';

/// The [ImageProvider] for a ready [image], or null when it is missing.
///
/// Native builds show the cached file; the web build has no file system and
/// gets the downloaded bytes instead.
ImageProvider? resolvedImageProvider(ResolvedImage image) {
  if (!image.isReady) {
    return null;
  }
  final bytes = image.bytes;
  if (bytes != null) {
    return MemoryImage(bytes);
  }
  final path = image.filePath;
  return path == null ? null : fileImageProvider(path);
}
