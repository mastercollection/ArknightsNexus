import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data_sources/image_source.dart';
import '../widgets/cached_image.dart';

const _operatorSilhouetteAsset = 'assets/icons/operator-silhouette.svg';

/// Skeleton shown while a remote image resolves: silhouette over a soft
/// radial glow (the `el-skeleton` template used by the Vue components).
class _SilhouetteSkeleton extends StatelessWidget {
  const _SilhouetteSkeleton({required this.iconFraction});

  final double iconFraction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final iconSize = constraints.biggest.shortestSide * iconFraction;
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0x05FFFFFF),
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.1,
              colors: [Color(0x245EB6FF), Color(0x005EB6FF)],
              stops: [0, 0.64],
            ),
          ),
          child: Center(
            child: Opacity(
              opacity: 0.94,
              child: SvgPicture.asset(
                _operatorSilhouetteAsset,
                width: iconSize,
                height: iconSize,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// `ItemIcon.vue`: 72px rounded tile with a 58px contained icon.
class ItemIcon extends StatelessWidget {
  const ItemIcon({
    required this.itemId,
    required this.name,
    this.iconId,
    this.size = 72,
    this.fixedContent = false,
    super.key,
  });

  final String itemId;
  final String? iconId;
  final String name;
  final double size;

  /// Mirrors a Vue `class="h-[N] w-[N]"` override on `ItemIcon.vue`: only the
  /// outer box changes size while the 18px radius, 58px image and 0.72rem
  /// fallback keep their CSS sizes. A larger image overflows the grid track
  /// from the top-left and is clipped by the box, exactly like the web app.
  final bool fixedContent;

  @override
  Widget build(BuildContext context) {
    final resolvedId =
        (iconId?.trim().isNotEmpty ?? false) ? iconId!.trim() : itemId.trim();
    final scale = fixedContent ? 1.0 : size / 72;
    final fallback = Center(
      child: Text(
        name.length > 2 ? name.substring(0, 2) : name,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11.52 * scale,
          height: 1.25,
          fontWeight: FontWeight.w700,
          color: const Color(0xE0DFE8FF),
        ),
      ),
    );

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        // The root is a <div>: `border border-soft` has no border-style (and
        // so no width) without a CSS reset.
        color: const Color(0xE6071224),
        borderRadius: BorderRadius.circular(18 * scale),
      ),
      child: resolvedId.isEmpty
          ? fallback
          : fixedContent
              ? _fixedContentImage(resolvedId, fallback)
              : Center(
                  child: CachedImage(
                    kind: CachedImageKind.itemIcon,
                    id: resolvedId,
                    size: 58 * scale,
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.zero,
                    fit: BoxFit.contain,
                    loading: SizedBox(
                      width: size,
                      height: size,
                      child: const _SilhouetteSkeleton(iconFraction: 40 / 72),
                    ),
                    placeholder: fallback,
                  ),
                ),
    );
  }

  Widget _fixedContentImage(String resolvedId, Widget fallback) {
    // No border is rendered, so the content box is the whole box.
    final inner = size;
    final overflowing = inner < 58;
    final image = CachedImage(
      kind: CachedImageKind.itemIcon,
      id: resolvedId,
      size: 58,
      shape: BoxShape.rectangle,
      borderRadius: BorderRadius.zero,
      fit: BoxFit.contain,
      loading: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: inner,
        maxWidth: inner,
        minHeight: inner,
        maxHeight: inner,
        child: _SilhouetteSkeleton(iconFraction: 40 / inner),
      ),
      placeholder: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: inner,
        maxWidth: inner,
        minHeight: inner,
        maxHeight: inner,
        child: fallback,
      ),
    );
    if (!overflowing) {
      return Center(child: image);
    }
    return OverflowBox(
      alignment: Alignment.topLeft,
      minWidth: 58,
      maxWidth: 58,
      minHeight: 58,
      maxHeight: 58,
      child: image,
    );
  }
}
