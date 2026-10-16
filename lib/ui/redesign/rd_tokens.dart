import 'package:flutter/widgets.dart';

/// Tokens of the redesign, palette A ("Graphite · Iris").
///
/// Elevation is a step between the surfaces plus a hairline, never a shadow:
/// [bg] < [surface1] (rail, sidebar, app bars) < [surface2] (cards) <
/// [surface3] (inner tiles, fields, portrait boxes). The pixel-parity tokens
/// of the Tauri port stay in `nexus_tokens.dart`.
class RdColors {
  const RdColors._();

  // Surfaces.
  static const bg = Color(0xFF0B0D11);
  static const surface1 = Color(0xFF111419);
  static const surface2 = Color(0xFF161A21);
  static const surface3 = Color(0xFF1D222B);

  /// Control borders (fields, outlined buttons, chips) and pane dividers.
  static const border = Color(0xFF252B35);

  /// Card outlines and separators inside a surface (`rgba(255,255,255,0.06)`).
  static const hairline = Color(0x0FFFFFFF);

  /// Grip of a pane resize handle.
  static const handle = Color(0xFF3A4250);

  // Text.
  static const text = Color(0xFFECEEF2);
  static const text2 = Color(0xFFAEB4C0);

  /// Helper text, captions, placeholders, inactive icons.
  static const text3 = Color(0xFF828A9A);

  // Accent.
  static const accent = Color(0xFF7C8CFF);

  /// Links, the icon of a selected navigation item, hover of [accent].
  static const accentHover = Color(0xFF97A4FF);
  static const onAccent = Color(0xFF0B0D11);

  /// Fill of a selected item / chip / segment (`rgba(124,140,255,0.14)`).
  static const accentSoft = Color(0x247C8CFF);

  /// Outline of a selected chip and the focus ring (`rgba(124,140,255,0.45)`).
  static const accentLine = Color(0x737C8CFF);

  /// Text on [accentSoft].
  static const accentText = Color(0xFFC9D0FF);

  // Status.
  /// Rarity stars only.
  static const rarity = Color(0xFFF2B544);

  /// Operators the selected region has not released yet.
  static const unreleased = Color(0xFFC39BFF);
  static const unreleasedFill = Color(0x24C39BFF); // rgba(195,155,255,0.14)
  static const unreleasedLine = Color(0x73C39BFF); // rgba(195,155,255,0.45)

  /// Opaque badge fill over a portrait.
  static const unreleasedSolid = Color(0xFF241D33);

  static const success = Color(0xFF4ADE9A);
  static const successFill = Color(0x1F4ADE9A);
  static const warning = Color(0xFFF5A524);
  static const warningFill = Color(0x1FF5A524); // rgba(245,165,36,0.12)
  static const warningText = Color(0xFFF5C46A);
  static const danger = Color(0xFFFF7A6B);
  static const dangerFill = Color(0x1FFF7A6B);
  static const dangerLine = Color(0x59FF7A6B);
  static const dangerText = Color(0xFFFFB4AA);

  /// Opaque [dangerFill] over surface-2 (error toasts, a pending removal).
  static const dangerSolid = Color(0xFF32252A);

  /// Neutral white overlays by percentage: insets, skeletons, tracks.
  static const white3 = Color(0x08FFFFFF); // rgba(255,255,255,0.03)
  static const white5 = Color(0x0DFFFFFF); // rgba(255,255,255,0.05)
  static const white8 = Color(0x14FFFFFF); // rgba(255,255,255,0.08)
  static const white10 = Color(0x1AFFFFFF); // rgba(255,255,255,0.1)
  static const white14 = Color(0x24FFFFFF); // rgba(255,255,255,0.14)
  static const white20 = Color(0x33FFFFFF); // rgba(255,255,255,0.2)

  /// Modal barrier of dialogs and sheets (50% black).
  static const barrier = Color(0x80000000);

  /// Dimming veil over a disabled field.
  static const disabledVeil = Color(0x8C0B0D11);

  // Role names the screens use; each is one of the palette tokens above.

  /// Sidebar, icon rail, bottom tab bar, PC detail pane.
  static const rail = surface1;

  /// Page header bars.
  static const header = surface1;
  static const card = surface2;
  static const inner = surface3;
  static const inner2 = surface3;

  /// Portrait / icon boxes.
  static const portrait = surface3;

  /// Dropdown fields.
  static const field = surface3;
  static const segmentTrack = surface3;
  static const segmentOn = accentSoft;

  /// Text on a selected segment / chip.
  static const onSegment = accentText;

  /// Bottom sheets and dialogs.
  static const sheet = surface2;

  /// Option rows inside a sheet.
  static const sheetOption = surface3;

  static const stateTitle = text;
  static const heading = text;

  /// Body copy of descriptions.
  static const body = text;
  static const secondary = text2;
  static const secondary2 = text2;
  static const muted = text3;
  static const placeholder = text3;

  /// Secondary accent of glyphs (portrait initials use [text2]).
  static const cyan = accentHover;

  /// Rarity stars and the favorite star.
  static const gold = rarity;

  static const warnBg = warningFill;
  static const warnText = warningText;

  static const line = hairline;
  static const line2 = hairline;
  static const line3 = border;
  static const soft = Color(0x0FFFFFFF); // rgba(255,255,255,0.06)
  static const soft2 = Color(0x0AFFFFFF); // rgba(255,255,255,0.04)

  static const chipOnBorder = accentLine;
  static const chipOnFill = accentSoft;
  static const searchBorder = border;

  /// Accent-tinted ("tonal") buttons.
  static const tonalFill = accentSoft;
  static const tonalBorder = accentLine;

  /// Outlined accent link buttons (retry, open detail, add).
  static const linkFill = accentSoft;
  static const linkBorder = accentLine;
  static const linkText = accentText;

  /// Text links ("계획 열기", "+ 플랜에 추가").
  static const link = accentHover;

  /// Runs chip of the farming rows, team chips.
  static const blueFill = accentSoft;
  static const blueText = accentText;

  /// Sanity chip / caution badge fill.
  static const goldFill = warningFill;
  static const dangerBorder = dangerLine;
}

/// Corner radii: 6 for chips, badges and small boxes, 10 for controls
/// (buttons, fields, rail items, inner tiles), 14 for cards and tiles, 20 for
/// sheets and dialogs.
class RdRadii {
  const RdRadii._();

  static const chip = 6.0;
  static const control = 10.0;
  static const inner = 10.0;
  static const small = 10.0;
  static const card = 14.0;
  static const tile = 14.0;
  static const sheet = 20.0;

  /// Fully round ends (status dots, switches); chips use [chip].
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

  /// Page title on PC (22/700).
  static const pageTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: RdColors.text,
  );

  /// Page title on phones (18/700).
  static const mobileTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: RdColors.text,
  );

  /// Section heading inside a page (15/600).
  static const sectionTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: RdColors.text,
  );
  static const body = TextStyle(fontSize: 14, color: RdColors.text);
  static const secondary = TextStyle(fontSize: 14, color: RdColors.secondary2);
  static const muted = TextStyle(fontSize: 13, color: RdColors.muted);
  static const small = TextStyle(fontSize: 12, color: RdColors.muted);

  /// Description line under a plan section heading.
  static const caption = TextStyle(
    fontSize: 12,
    height: 1.45,
    color: RdColors.secondary2,
  );

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
