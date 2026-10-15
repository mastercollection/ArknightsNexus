import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
