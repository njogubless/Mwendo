import 'package:flutter/material.dart';

import 'mw_colors.dart';
import 'mw_tokens.dart';

const _fontFamily = 'PlusJakartaSans';

/// Converts the design system's `em` letter-spacing to logical pixels.
TextStyle _style(double size, double height, FontWeight weight, double trackingEm) => TextStyle(
  fontFamily: _fontFamily,
  fontSize: size,
  height: height / size,
  fontWeight: weight,
  letterSpacing: trackingEm * size,
);

/// Type scale from the Stitch DESIGN.md, mapped onto Material roles:
///
/// | Material        | Design token         |
/// |-----------------|----------------------|
/// | displayLarge    | display-lg (44)      |
/// | displayMedium   | display-lg-mobile    |
/// | headlineLarge   | headline-lg (32)     |
/// | headlineMedium  | headline-lg-mobile   |
/// | headlineSmall   | headline-md (22)     |
/// | titleLarge      | headline-sm (18)     |
/// | bodyLarge/M/S   | body-lg/md/sm        |
/// | labelLarge/M/S  | label-lg/md/sm       |
TextTheme _textTheme(MwColors c) {
  final base = TextTheme(
    displayLarge: _style(44, 52, FontWeight.w600, -0.03),
    displayMedium: _style(34, 42, FontWeight.w600, -0.025),
    headlineLarge: _style(32, 40, FontWeight.w600, -0.02),
    headlineMedium: _style(26, 34, FontWeight.w600, -0.015),
    headlineSmall: _style(22, 30, FontWeight.w600, -0.01),
    titleLarge: _style(18, 26, FontWeight.w600, -0.005),
    titleMedium: _style(15, 22, FontWeight.w600, 0),
    titleSmall: _style(14, 20, FontWeight.w600, 0.01),
    bodyLarge: _style(17, 26, FontWeight.w400, 0),
    bodyMedium: _style(15, 24, FontWeight.w400, 0.005),
    bodySmall: _style(13, 20, FontWeight.w400, 0.01),
    labelLarge: _style(14, 20, FontWeight.w600, 0.01),
    labelMedium: _style(12, 16, FontWeight.w600, 0.02),
    labelSmall: _style(11, 14, FontWeight.w500, 0.04),
  );
  return base.apply(bodyColor: c.textPrimary, displayColor: c.textPrimary);
}

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.light ? MwColors.light : MwColors.dark;
  final textTheme = _textTheme(c);

  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.action,
    onPrimary: c.onAction,
    primaryContainer: c.successTint,
    onPrimaryContainer: c.onSuccessTint,
    secondary: c.accent,
    onSecondary: c.onAccent,
    secondaryContainer: c.accentTint,
    onSecondaryContainer: c.accentText,
    tertiary: c.gentle,
    onTertiary: c.onAction,
    tertiaryContainer: c.gentleTint,
    onTertiaryContainer: c.onGentleTint,
    error: c.danger,
    onError: c.onAction,
    surface: c.canvas,
    onSurface: c.textPrimary,
    onSurfaceVariant: c.textSecondary,
    surfaceContainerLowest: c.surface,
    surfaceContainerLow: c.surfaceWarm,
    surfaceContainer: c.sunken,
    surfaceContainerHigh: c.sunken,
    surfaceContainerHighest: c.sand,
    outline: c.textTertiary,
    outlineVariant: c.border,
    shadow: c.shadow,
    scrim: c.scrim,
    inverseSurface: c.textPrimary,
    onInverseSurface: c.canvas,
  );

  final inputBorder = OutlineInputBorder(borderRadius: BorderRadius.circular(MwRadii.lg), borderSide: BorderSide.none);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: _fontFamily,
    textTheme: textTheme,
    scaffoldBackgroundColor: c.canvas,
    extensions: [c],
    splashFactory: NoSplash.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: c.canvas,
      foregroundColor: c.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
    ),
    dividerTheme: DividerThemeData(color: c.hairline, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.sunken,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(borderSide: BorderSide(color: c.accent, width: 1.5)),
      errorBorder: inputBorder.copyWith(borderSide: BorderSide(color: c.gentle, width: 1.5)),
      focusedErrorBorder: inputBorder.copyWith(borderSide: BorderSide(color: c.gentle, width: 1.5)),
      labelStyle: textTheme.bodyMedium?.copyWith(color: c.textSecondary),
      hintStyle: textTheme.bodyMedium?.copyWith(color: c.textTertiary),
      errorStyle: textTheme.bodySmall?.copyWith(color: c.onGentleTint),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.textPrimary,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: c.canvas),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MwRadii.lg)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      showDragHandle: true,
      dragHandleColor: c.border,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(MwRadii.xl))),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.action, linearTrackColor: c.sunken),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: c.canvas,
      indicatorColor: c.accentTint,
      selectedIconTheme: IconThemeData(color: c.accentText),
      unselectedIconTheme: IconThemeData(color: c.textSecondary),
      selectedLabelTextStyle: textTheme.labelMedium?.copyWith(color: c.accentText),
      unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(color: c.textSecondary),
    ),
  );
}

extension MwThemeX on BuildContext {
  MwColors get mwColors => Theme.of(this).extension<MwColors>()!;
  TextTheme get text => Theme.of(this).textTheme;
}
