import 'package:flutter/widgets.dart';

/// Tokens of the redesign canvas ("ArknightsNexus 레이아웃 제안").
///
/// The pixel-parity tokens of the Tauri port stay in `nexus_tokens.dart`;
/// redesigned screens use these instead.
class RdColors {
  const RdColors._();

  static const bg = Color(0xFF050914);

  /// Sidebar, icon rail, bottom tab bar, PC detail pane.
  static const rail = Color(0xFF080E1C);

  /// Page header bars.
  static const header = Color(0xFF070C19);
  static const card = Color(0xFF0C1426);
  static const inner = Color(0xFF111B30);
  static const inner2 = Color(0xFF0F1729);

  /// Portrait / icon boxes.
  static const portrait = Color(0xFF16223A);

  static const text = Color(0xFFF5F7FF);
  static const secondary = Color(0xFFC9D6EE);
  static const secondary2 = Color(0xFFB7C3D9);
  static const muted = Color(0xFF9AA6BD);
  static const placeholder = Color(0xFF7D8AA3);
  static const accent = Color(0xFF85B6FF);
  static const onAccent = Color(0xFF06101F);
  static const cyan = Color(0xFF8BD6FF);
  static const gold = Color(0xFFFFCF70);
  static const success = Color(0xFF6EE7A8);
  static const danger = Color(0xFFFF8A8A);

  static const warnBg = Color(0x14FFCF70); // rgba(255,207,112,0.08)
  static const warnText = Color(0xFFFFE2A8);

  static const line = Color(0x0FFFFFFF); // rgba(255,255,255,0.06)
  static const line2 = Color(0x12FFFFFF); // rgba(255,255,255,0.07)
  static const line3 = Color(0x1FFFFFFF); // rgba(255,255,255,0.12)
  static const soft = Color(0x0FFFFFFF); // rgba(255,255,255,0.06)
  static const soft2 = Color(0x0AFFFFFF); // rgba(255,255,255,0.04)

  /// White overlays of the canvas that the line/soft tokens do not name,
  /// by percentage: insets, skeletons, field borders, drag handles.
  static const white3 = Color(0x08FFFFFF); // rgba(255,255,255,0.03)
  static const white5 = Color(0x0DFFFFFF); // rgba(255,255,255,0.05)
  static const white8 = Color(0x14FFFFFF); // rgba(255,255,255,0.08)
  static const white10 = Color(0x1AFFFFFF); // rgba(255,255,255,0.1)
  static const white14 = Color(0x24FFFFFF); // rgba(255,255,255,0.14)
  static const white20 = Color(0x33FFFFFF); // rgba(255,255,255,0.2)

  /// Modal barrier of dialogs and sheets (50% black).
  static const barrier = Color(0x80000000);

  static const chipOnBorder = Color(0x9985B6FF); // rgba(133,182,255,0.6)
  static const chipOnFill = Color(0x2985B6FF); // rgba(133,182,255,0.16)
  static const searchBorder = Color(0x4785B6FF); // rgba(133,182,255,0.28)

  /// Accent-tinted ("tonal") buttons.
  static const tonalFill = Color(0x2485B6FF); // rgba(133,182,255,0.14)
  static const tonalBorder = Color(0x6685B6FF); // rgba(133,182,255,0.4)

  /// Outlined accent link buttons (retry, open detail, add).
  static const linkFill = Color(0x1F85B6FF);
  static const linkBorder = Color(0x8085B6FF);
  static const linkText = Color(0xFFDBE8FF);

  /// Light-blue text links ("계획 열기 →", "+ 플랜에 추가").
  static const link = Color(0xFFA9C8FF);

  /// Text on a selected segment / chip.
  static const onSegment = Color(0xFFF3F8FF);

  /// Error banners and panels.
  static const dangerFill = Color(0x14FF7878);
  static const dangerBorder = Color(0x33FF7878);
  static const dangerText = Color(0xEBFFD6D6);

  /// Runs chip of the farming rows, team chips (`rgba(113,165,255,0.16)`).
  static const blueFill = Color(0x2971A5FF);
  static const blueText = Color(0xFFDCE9FF);

  /// Gold sanity chip / gold badge fill (`rgba(255,207,112,0.14)`).
  static const goldFill = Color(0x24FFCF70);

  static const segmentTrack = Color(0xFF111A2C);
  static const segmentOn = Color(0xE65C94DC); // rgba(92,148,220,0.9)

  /// Dropdown fields.
  static const field = Color(0xFF121A2C);

  /// Body copy of descriptions (`#e6ecf8`).
  static const body = Color(0xFFE6ECF8);

  static const sheet = Color(0xFF141414);
  static const sheetOption = Color(0xFF1D1E1F);
}

class RdRadii {
  const RdRadii._();

  static const card = 20.0;
  static const tile = 18.0;
  static const inner = 14.0;
  static const control = 12.0;
  static const small = 10.0;
  static const pill = 999.0;
}

/// Layout classes of the redesign: phones get bottom tabs, everything wider
/// gets the 76px icon rail; the home page shows the full sidebar when there is
/// room for it.
enum RdLayout { compact, medium, expanded }

class RdBreakpoints {
  const RdBreakpoints._();

  /// Below this width: mobile layout (bottom tab bar, single pane).
  static const medium = 720.0;

  /// From this width: master-detail panes and the full home sidebar.
  static const expanded = 1200.0;

  static RdLayout of(double width) {
    if (width < medium) {
      return RdLayout.compact;
    }
    return width < expanded ? RdLayout.medium : RdLayout.expanded;
  }
}

extension RdLayoutContext on BuildContext {
  RdLayout get rdLayout => RdBreakpoints.of(MediaQuery.sizeOf(this).width);
}

class RdText {
  const RdText._();

  static const fontFamily = 'Noto Sans KR';
  static const fontFallback = ['Segoe UI', 'Malgun Gothic', 'sans-serif'];
  static const monoFamily = 'JetBrains Mono';
  static const monoFallback = ['Consolas', 'Roboto Mono', 'monospace'];

  static const eyebrow = TextStyle(
    fontSize: 12,
    letterSpacing: 1.7,
    color: RdColors.muted,
  );
  static const pageTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: RdColors.text,
  );
  static const mobileTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: RdColors.text,
  );
  static const sectionTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: RdColors.text,
  );
  static const body = TextStyle(fontSize: 14, color: RdColors.text);
  static const secondary = TextStyle(fontSize: 14, color: RdColors.secondary2);
  static const muted = TextStyle(fontSize: 13, color: RdColors.muted);
  static const small = TextStyle(fontSize: 12, color: RdColors.muted);

  static TextStyle mono({
    double fontSize = 14,
    Color color = RdColors.text,
    FontWeight fontWeight = FontWeight.w500,
  }) =>
      TextStyle(
        fontFamily: monoFamily,
        fontFamilyFallback: monoFallback,
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight,
      );
}
