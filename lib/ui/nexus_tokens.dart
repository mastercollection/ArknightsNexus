import 'package:flutter/material.dart';

/// Design tokens ported from the Tauri app's `uno.config.ts` theme.
///
/// Sizes in the Vue templates are rem-based; 1rem = 16 logical px here.
class NexusColors {
  const NexusColors._();

  static const app = Color(0xFF050914);
  static const shell = Color(0xFF09101E);
  static const surface = Color(0xFF0A0F1E);
  static const surface2 = Color(0xFF10141C);
  static const line = Color(0x14FFFFFF); // rgba(255,255,255,0.08)
  static const soft = Color(0x0FFFFFFF); // rgba(255,255,255,0.06)
  static const muted = Color(0xADC4CDDE); // rgba(196,205,222,0.68)
  static const text = Color(0xFFF5F7FF);
  static const accent = Color(0xFF85B6FF);
  static const accent2 = Color(0xFF8BD6FF);
  static const gold = Color(0xFFFFCF70);

  /// `rgba(10,15,30,0.78)` — panel-soft / stat-card fill.
  static const softFill = Color(0xC70A0F1E);

  /// `linear-gradient(180deg, rgba(16,20,28,0.96), rgba(9,12,18,0.96))`.
  static const panelGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xF510141C), Color(0xF5090C12)],
  );

  /// Body text used inside chips: `rgba(245,247,255,0.88)`.
  static const chipText = Color(0xE0F5F7FF);

  /// Chromium dark-scheme `ButtonFace`, visible under translucent button
  /// backgrounds (the Tauri app has no CSS reset).
  static const buttonFace = Color(0xFF6B6B6B);

  /// `text-slate-300/88`.
  static const slate300 = Color(0xE0CBD5E1);
}

class NexusRadii {
  const NexusRadii._();

  static const panel = 24.0;
  static const tile = 22.0;
  static const card = 20.0;
  static const pill = 999.0;
}

class NexusText {
  const NexusText._();

  static const fontFamily = 'Segoe UI';
  static const fontFallback = ['Noto Sans KR', 'Malgun Gothic', 'sans-serif'];

  /// CSS `line-height: normal` as Chromium computes it for Korean text: the
  /// Noto Sans KR ascent (1.16em) and descent (0.288em), each rounded to
  /// whole pixels. Returned as a [TextStyle.height] multiplier; pair it with
  /// [TextLeadingDistribution.even].
  static double normalHeight(double fontSize) =>
      ((1.16 * fontSize).roundToDouble() + (0.288 * fontSize).roundToDouble()) /
      fontSize;

  /// [normalHeight] for [text]: lines without any non-Latin glyph only use
  /// Segoe UI, whose rounded ascent (1.08em) and descent (0.251em) are smaller.
  static double normalHeightFor(String text, double fontSize) {
    final latinOnly = text.runes.every((rune) => rune < 0x2000);
    if (!latinOnly) {
      return normalHeight(fontSize);
    }
    return ((1.08 * fontSize).roundToDouble() +
            (0.251 * fontSize).roundToDouble()) /
        fontSize;
  }

  /// `section-title`: 1.45rem / 700.
  static const sectionTitle = TextStyle(
    fontSize: 23.2,
    height: 1.25,
    fontWeight: FontWeight.w700,
    color: NexusColors.text,
  );

  /// `eyebrow`: 0.78rem, letter-spacing 0.12em, uppercase, muted.
  static const eyebrow = TextStyle(
    fontSize: 12.48,
    letterSpacing: 1.5,
    color: NexusColors.muted,
  );

  /// `muted-copy`.
  static const muted = TextStyle(color: NexusColors.muted);

  static const body = TextStyle(color: NexusColors.text, fontSize: 16);
}

/// Breakpoints used by the UnoCSS templates (`sm`, `md`, `lg`, `xl`).
class NexusBreakpoints {
  const NexusBreakpoints._();

  static const sm = 640.0;
  static const md = 768.0;
  static const lg = 1024.0;
  static const xl = 1280.0;

  /// `shell-wrap` max width (72rem).
  static const shellMaxWidth = 1152.0;
}
