import 'package:flutter/material.dart';

import '../ui/nexus_controls.dart';
import '../ui/nexus_tokens.dart';

class NexusTheme {
  const NexusTheme._();

  static TextTheme _withoutTracking(TextTheme theme) {
    TextStyle? zero(TextStyle? style) => style?.copyWith(letterSpacing: 0);
    return TextTheme(
      displayLarge: zero(theme.displayLarge),
      displayMedium: zero(theme.displayMedium),
      displaySmall: zero(theme.displaySmall),
      headlineLarge: zero(theme.headlineLarge),
      headlineMedium: zero(theme.headlineMedium),
      headlineSmall: zero(theme.headlineSmall),
      titleLarge: zero(theme.titleLarge),
      titleMedium: zero(theme.titleMedium),
      titleSmall: zero(theme.titleSmall),
      bodyLarge: zero(theme.bodyLarge),
      bodyMedium: zero(theme.bodyMedium),
      bodySmall: zero(theme.bodySmall),
      labelLarge: zero(theme.labelLarge),
      labelMedium: zero(theme.labelMedium),
      labelSmall: zero(theme.labelSmall),
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: NexusColors.accent,
      brightness: Brightness.dark,
      surface: NexusColors.surface,
    ).copyWith(
      primary: ElementDark.primary,
      surface: NexusColors.surface,
      onSurface: NexusColors.text,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      // CSS text has no tracking by default; Material 3's type scale adds
      // 0.1–0.5px letter spacing (bodyMedium, the default text style, has
      // 0.25px), which widened every line compared to the Tauri app.
      typography: Typography.material2021(
        englishLike: _withoutTracking(Typography.englishLike2021),
        dense: _withoutTracking(Typography.dense2021),
        tall: _withoutTracking(Typography.tall2021),
      ),
      colorScheme: colorScheme,
      fontFamily: NexusText.fontFamily,
      fontFamilyFallback: NexusText.fontFallback,
      scaffoldBackgroundColor: NexusColors.app,
      canvasColor: NexusColors.app,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: const Color(0x0FFFFFFF),
      dividerColor: NexusColors.line,
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          color: NexusColors.text,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: NexusColors.text,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        // Chromium's `line-height: normal` for 16px Korean text is 24px
        // (rounded Noto Sans KR ascent 19 + descent 5); Material's 1.43
        // made every default line ~1px shorter than the Tauri app.
        bodyLarge:
            TextStyle(color: NexusColors.text, fontSize: 16, height: 1.5),
        bodyMedium: TextStyle(
          color: NexusColors.text,
          fontSize: 16,
          height: 1.5,
        ),
        bodySmall: TextStyle(color: NexusColors.muted, fontSize: 13),
      ).apply(bodyColor: NexusColors.text, displayColor: NexusColors.text),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: ElementDark.textRegular,
        selectionColor: Color(0x55409EFF),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFF303133),
          borderRadius: BorderRadius.circular(4),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: ElementDark.overlay,
        contentTextStyle: TextStyle(color: ElementDark.textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: ElementDark.overlay,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      scrollbarTheme: const ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(Color(0x33FFFFFF)),
      ),
    );
  }
}
