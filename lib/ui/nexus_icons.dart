import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Element Plus icon glyphs (`@element-plus/icons-vue`, 1024 viewBox) for the
/// Material [IconData] the screens pass around, so icons render with the same
/// outlines as the Tauri app. Unmapped icons fall back to the Material glyph.
class NexusIcon extends StatelessWidget {
  const NexusIcon(this.icon, {this.size = 16, this.color, super.key});

  final IconData icon;
  final double size;
  final Color? color;

  static final Map<IconData, String> _paths = {
    Icons.check_circle: _successFilled,
    Icons.info: _infoFilled,
    Icons.cancel: _circleCloseFilled,
    Icons.error: _circleCloseFilled,
  };

  static final Map<String, String> _svgCache = {};

  static String _svg(String paths) => _svgCache.putIfAbsent(
        paths,
        () => '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">'
            '${paths.split('|').map((d) => '<path fill="#fff" d="$d"/>').join()}'
            '</svg>',
      );

  @override
  Widget build(BuildContext context) {
    final paths = _paths[icon];
    final effectiveColor = color ?? IconTheme.of(context).color;
    if (paths == null) {
      return Icon(icon, size: size, color: effectiveColor);
    }
    // Like [Icon]: keeps its size and centres itself in tight constraints.
    return Align(
      widthFactor: 1,
      heightFactor: 1,
      child: SizedBox.square(
        dimension: size,
        child: SvgPicture.string(
          _svg(paths),
          width: size,
          height: size,
          colorFilter: effectiveColor == null
              ? null
              : ColorFilter.mode(effectiveColor, BlendMode.srcIn),
        ),
      ),
    );
  }
}

const _successFilled =
    'M512 64a448 448 0 1 1 0 896 448 448 0 0 1 0-896m-55.808 536.384-99.52-99.584a38.4 38.4 0 1 0-54.336 54.336l126.72 126.72a38.27 38.27 0 0 0 54.336 0l262.4-262.464a38.4 38.4 0 1 0-54.272-54.336z';
const _infoFilled =
    'M512 64a448 448 0 1 1 0 896.064A448 448 0 0 1 512 64m67.2 275.072c33.28 0 60.288-23.104 60.288-57.344s-27.072-57.344-60.288-57.344c-33.28 0-60.16 23.104-60.16 57.344s26.88 57.344 60.16 57.344M590.912 699.2c0-6.848 2.368-24.64 1.024-34.752l-52.608 60.544c-10.88 11.456-24.512 19.392-30.912 17.28a12.99 12.99 0 0 1-8.256-14.72l87.68-276.992c7.168-35.136-12.544-67.2-54.336-71.296-44.096 0-108.992 44.736-148.48 101.504 0 6.784-1.28 23.68.064 33.792l52.544-60.608c10.88-11.328 23.552-19.328 29.952-17.152a12.8 12.8 0 0 1 7.808 16.128L388.48 728.576c-10.048 32.256 8.96 63.872 55.04 71.04 67.84 0 107.904-43.648 147.456-100.416z';
const _circleCloseFilled =
    'M512 64a448 448 0 1 1 0 896 448 448 0 0 1 0-896m0 393.664L407.936 353.6a38.4 38.4 0 1 0-54.336 54.336L457.664 512 353.6 616.064a38.4 38.4 0 1 0 54.336 54.336L512 566.336 616.064 670.4a38.4 38.4 0 1 0 54.336-54.336L566.336 512 670.4 407.936a38.4 38.4 0 1 0-54.336-54.336z';
