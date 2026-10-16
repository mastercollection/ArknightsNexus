import 'package:flutter/material.dart';

import '../ui/nexus_tokens.dart';
import '../ui/redesign/rd_tokens.dart';

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
      seedColor: RdColors.accent,
      brightness: Brightness.dark,
      surface: RdColors.surface2,
    ).copyWith(
      primary: RdColors.accent,
      onPrimary: RdColors.onAccent,
      secondary: RdColors.accentHover,
      surface: RdColors.surface2,
      onSurface: RdColors.text,
      onSurfaceVariant: RdColors.text2,
      outline: RdColors.border,
      outlineVariant: RdColors.hairline,
      error: RdColors.danger,
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
      scaffoldBackgroundColor: RdColors.bg,
      canvasColor: RdColors.bg,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: RdColors.white5,
      focusColor: RdColors.accentSoft,
      dividerColor: RdColors.hairline,
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          color: RdColors.text,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: RdColors.text,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        // Chromium's `line-height: normal` for 16px Korean text is 24px
        // (rounded Noto Sans KR ascent 19 + descent 5); Material's 1.43
        // made every default line ~1px shorter than the Tauri app.
        bodyLarge: TextStyle(color: RdColors.text, fontSize: 16, height: 1.5),
        bodyMedium: TextStyle(
          color: RdColors.text,
          fontSize: 16,
          height: 1.5,
        ),
        bodySmall: TextStyle(color: RdColors.text3, fontSize: 13),
      ).apply(bodyColor: RdColors.text, displayColor: RdColors.text),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: RdColors.accent,
        selectionColor: Color(0x597C8CFF), // accent at 35%
        selectionHandleColor: RdColors.accent,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: RdColors.surface3,
          borderRadius: BorderRadius.circular(RdRadii.chip),
          border: Border.all(color: RdColors.border),
        ),
        textStyle: const TextStyle(color: RdColors.text, fontSize: 12),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: RdColors.surface3,
        contentTextStyle: TextStyle(color: RdColors.text),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: RdColors.surface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RdRadii.sheet),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: RdColors.surface3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RdRadii.control),
          side: const BorderSide(color: RdColors.border),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: RdColors.accent,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.dragged) ||
                  states.contains(WidgetState.hovered)
              ? RdColors.text3
              : RdColors.handle,
        ),
        radius: const Radius.circular(RdRadii.pill),
      ),
    );
  }
}
