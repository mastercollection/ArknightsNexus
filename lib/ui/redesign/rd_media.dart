import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data_sources/image_source.dart';
import '../../widgets/cached_image.dart';
import 'rd_tokens.dart';

/// App mark (`nexus-beacon.svg`) of the sidebar, home and settings headers.
const rdAppIconAsset = 'assets/icons/app/nexus-beacon.svg';

/// The app mark in its rounded navy box (32px in the brand rows, 28px in the
/// settings header).
class RdAppMark extends StatelessWidget {
  const RdAppMark({this.size = 32, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all((size * 3 / 16).roundToDouble()),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1730),
          borderRadius: BorderRadius.circular((size * 9 / 32).roundToDouble()),
          border: Border.all(color: const Color(0x598BD6FF)),
        ),
        child: SvgPicture.asset(rdAppIconAsset),
      ),
    );
  }
}

/// Elite phase icon (`assets/icons/elite/N.webp`) for E0-E2.
String? rdEliteAsset(int? elite) {
  if (elite == null || elite < 0 || elite > 2) {
    return null;
  }
  return 'assets/icons/elite/$elite.webp';
}

/// Mastery icon (`assets/icons/skill/N.png`); only skill levels 8-10
/// (M1-M3) have one.
String? rdMasteryAsset(int level) =>
    level >= 8 && level <= 10 ? 'assets/icons/skill/$level.png' : null;

/// Elite phase icon; `E{n}` text when the phase has no icon.
class RdEliteIcon extends StatelessWidget {
  const RdEliteIcon(
    this.elite, {
    this.size = 18,
    this.excludeSemantics = false,
    super.key,
  });

  final int elite;
  final double size;

  /// Leaves the icon out of the semantics tree (the label already says it).
  final bool excludeSemantics;

  @override
  Widget build(BuildContext context) {
    final asset = rdEliteAsset(elite);
    if (asset == null) {
      return Text('E$elite');
    }
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      excludeFromSemantics: excludeSemantics,
      semanticLabel: 'Elite $elite',
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

/// Mastery icon for skill levels 8-10; `M{rank}` in [fallbackStyle] when the
/// image cannot be loaded.
class RdMasteryIcon extends StatelessWidget {
  const RdMasteryIcon(
    this.level, {
    this.size = 22,
    this.semanticLabel,
    this.fallbackStyle,
    super.key,
  });

  final int level;
  final double size;

  /// Spoken label; defaults to `M{rank}`.
  final String? semanticLabel;
  final TextStyle? fallbackStyle;

  @override
  Widget build(BuildContext context) {
    final rank = level - 7;
    return Image.asset(
      rdMasteryAsset(level)!,
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: semanticLabel ?? 'M$rank',
      errorBuilder: (context, error, stackTrace) =>
          Text('M$rank', style: fallbackStyle),
    );
  }
}

/// Cached operator portrait in a rounded `#16223a` box; the initial letter
/// stands in while the image loads or is missing.
class RdPortrait extends StatelessWidget {
  const RdPortrait({
    required this.charId,
    required this.name,
    required this.size,
    required this.radius,
    super.key,
  });

  final String charId;
  final String name;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty
        ? ''
        : String.fromCharCode(trimmed.runes.first).toUpperCase();
    final fallback = Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.32,
          fontWeight: FontWeight.w800,
          color: RdColors.cyan,
        ),
      ),
    );
    final id = charId.trim();
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: RdColors.portrait,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: id.isEmpty
          ? fallback
          : CachedImage(
              kind: CachedImageKind.portrait,
              id: id,
              size: size,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.zero,
              placeholder: fallback,
            ),
    );
  }
}
