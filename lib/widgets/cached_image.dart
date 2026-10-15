import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data_sources/image_source.dart';
import '../services/image_cache_service.dart';
import 'resolved_image_provider.dart';

/// Displays a cached remote image for a [CachedImageKind]/id pair.
///
/// While the image is loading or unavailable it shows [placeholder], so callers
/// can keep their existing fallback visuals. Successfully resolved images are
/// clipped to the requested [shape].
class CachedImage extends ConsumerStatefulWidget {
  const CachedImage({
    required this.kind,
    required this.id,
    required this.size,
    required this.placeholder,
    this.loading,
    this.shape = BoxShape.circle,
    this.borderRadius,
    this.fit = BoxFit.cover,
    super.key,
  });

  final CachedImageKind kind;
  final String id;
  final double size;
  final Widget placeholder;

  /// Shown while the image is being resolved; defaults to [placeholder].
  final Widget? loading;
  final BoxShape shape;
  final BorderRadius? borderRadius;
  final BoxFit fit;

  @override
  ConsumerState<CachedImage> createState() => _CachedImageState();
}

/// Images already resolved this session, per [ImageCacheService]: a page
/// that is opened again shows them in its first frame instead of a frame of
/// placeholders while the (already settled) lookup completes. Missing images
/// are not kept, so they are asked for again like before.
final _readyImages = Expando<Map<String, ResolvedImage>>('readyImages');

class _CachedImageState extends ConsumerState<CachedImage> {
  /// The resolved image when it was known before the first build.
  ResolvedImage? _ready;
  Future<ResolvedImage>? _future;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(CachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind || oldWidget.id != widget.id) {
      _resolve();
    }
  }

  void _resolve() {
    final service = ref.read(imageCacheServiceProvider);
    final request = ImageRequest(kind: widget.kind, id: widget.id);
    final ready = _readyImages[service] ??= {};
    _ready = ready[request.cacheKey];
    if (_ready != null) {
      _future = null;
      return;
    }
    _future = service.resolve(request).then((image) {
      if (image.isReady) {
        ready[request.cacheKey] = image;
      }
      return image;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ready = _ready;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: ready != null
          ? _image(ready)
          : FutureBuilder<ResolvedImage>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done &&
                    widget.loading != null) {
                  return widget.loading!;
                }
                return _image(snapshot.data);
              },
            ),
    );
  }

  Widget _image(ResolvedImage? resolved) {
    final provider = resolved == null ? null : resolvedImageProvider(resolved);
    if (provider == null) {
      return widget.placeholder;
    }

    final image = Image(
      image: provider,
      width: widget.size,
      height: widget.size,
      fit: widget.fit,
      errorBuilder: (context, error, stackTrace) => widget.placeholder,
    );

    if (widget.shape == BoxShape.rectangle &&
        widget.borderRadius == BorderRadius.zero) {
      return image;
    }
    if (widget.shape == BoxShape.circle) {
      return ClipOval(child: image);
    }

    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
      child: image,
    );
  }
}
