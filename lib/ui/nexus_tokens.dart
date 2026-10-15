import 'package:flutter/material.dart';

/// Design tokens ported from the Tauri app's `uno.config.ts` theme.
///
/// Sizes in the Vue templates are rem-based; 1rem = 16 logical px here.
class NexusColors {
  const NexusColors._();

  static const app = Color(0xFF050914);
  static const surface = Color(0xFF0A0F1E);
  static const line = Color(0x14FFFFFF); // rgba(255,255,255,0.08)
  static const muted = Color(0xADC4CDDE); // rgba(196,205,222,0.68)
  static const text = Color(0xFFF5F7FF);
  static const accent = Color(0xFF85B6FF);
}

class NexusRadii {
  const NexusRadii._();

  static const pill = 999.0;
}

class NexusText {
  const NexusText._();

  static const fontFamily = 'Segoe UI';
  static const fontFallback = ['Noto Sans KR', 'Malgun Gothic', 'sans-serif'];
}

/// Element Plus dark-theme palette, used where the Tauri app keeps stock
/// Element Plus controls (inputs, selects, sliders, drawers).
class ElementDark {
  const ElementDark._();

  static const primary = Color(0xFF409EFF);
  static const textRegular = Color(0xFFCFD3DC);
  static const textPrimary = Color(0xFFE5EAF3);
  static const overlay = Color(0xFF1D1E1F);
}
