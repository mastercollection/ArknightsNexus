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

class _CachedImageState extends ConsumerState<CachedImage> {
  late Future<ResolvedImage> _future;

  @override
  void initState() {
    super.initState();
    _future = _resolve();
  }

  @override
  void didUpdateWidget(CachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind || oldWidget.id != widget.id) {
      _future = _resolve();
    }
  }

  Future<ResolvedImage> _resolve() {
    return ref.read(imageCacheServiceProvider).resolve(
          ImageRequest(kind: widget.kind, id: widget.id),
        );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: FutureBuilder<ResolvedImage>(
        future: _future,
        builder: (context, snapshot) {
          final resolved = snapshot.data;
          if (snapshot.connectionState != ConnectionState.done &&
              widget.loading != null) {
            return widget.loading!;
          }
          final provider =
              resolved == null ? null : resolvedImageProvider(resolved);
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
        },
      ),
    );
  }
}
