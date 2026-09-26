import 'package:flutter/material.dart';

/// Mwendo colour tokens (docs/design/design-system.md).
///
/// Semantic names are used in widgets; raw brand hues (ochre, forest, …) are
/// exposed for data visualisation only. Values reconcile the Stitch DESIGN.md
/// prose palette with WCAG AA contrast (decisions D-002, D-003).
@immutable
class MwColors extends ThemeExtension<MwColors> {
  const MwColors({
    required this.canvas,
    required this.sunken,
    required this.surface,
    required this.surfaceWarm,
    required this.border,
    required this.hairline,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.action,
    required this.actionPressed,
    required this.onAction,
    required this.accent,
    required this.accentPressed,
    required this.onAccent,
    required this.accentText,
    required this.accentTint,
    required this.success,
    required this.successTint,
    required this.onSuccessTint,
    required this.gentle,
    required this.gentleTint,
    required this.onGentleTint,
    required this.sage,
    required this.sand,
    required this.danger,
    required this.scrim,
    required this.shadow,
  });

  /// Page background (Ivory).
  final Color canvas;

  /// Recessed areas: progress beds, inputs, secondary buttons (Sand).
  final Color sunken;

  /// Elevated cards (Ceramic).
  final Color surface;

  /// Alternate elevated surface (Warm Cream).
  final Color surfaceWarm;

  /// Solid hairline for card enclosures.
  final Color border;

  /// Translucent hairline for dividers.
  final Color hairline;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// Primary call-to-action fill (Forest). White text passes AA.
  final Color action;
  final Color actionPressed;
  final Color onAction;

  /// Highlight / progress / energy (Ochre). Use [onAccent] (charcoal) on it.
  final Color accent;
  final Color accentPressed;
  final Color onAccent;

  /// Ochre dark enough for text on light surfaces.
  final Color accentText;
  final Color accentTint;

  /// Completion states.
  final Color success;
  final Color successTint;
  final Color onSuccessTint;

  /// Gentle attention (Terracotta). Never used for failure language.
  final Color gentle;
  final Color gentleTint;
  final Color onGentleTint;

  /// Data-visualisation accents.
  final Color sage;
  final Color sand;

  /// Destructive actions only (delete account). Not for missed activities.
  final Color danger;
  final Color scrim;
  final Color shadow;

  static const light = MwColors(
    canvas: Color(0xFFF7F4EE),
    sunken: Color(0xFFEFEBE1),
    surface: Color(0xFFFFFFFF),
    surfaceWarm: Color(0xFFFAF8F4),
    border: Color(0xFFE8E3D7),
    hairline: Color(0x0F111315),
    textPrimary: Color(0xFF111315),
    textSecondary: Color(0xFF4A4D52),
    textTertiary: Color(0xFF6E7178),
    action: Color(0xFF245C4A),
    actionPressed: Color(0xFF1A4436),
    onAction: Color(0xFFFFFFFF),
    accent: Color(0xFFD49A45),
    accentPressed: Color(0xFFB88032),
    onAccent: Color(0xFF111315),
    accentText: Color(0xFF8A5A12),
    accentTint: Color(0xFFF6E7CF),
    success: Color(0xFF245C4A),
    successTint: Color(0xFFDCEBE3),
    onSuccessTint: Color(0xFF1A4436),
    gentle: Color(0xFFC86D51),
    gentleTint: Color(0xFFF7E3DB),
    onGentleTint: Color(0xFF7A3520),
    sage: Color(0xFF98A896),
    sand: Color(0xFFE6DFC8),
    danger: Color(0xFFA63D2A),
    scrim: Color(0x66111315),
    shadow: Color(0xFF241C15),
  );

  static const dark = MwColors(
    canvas: Color(0xFF121314),
    sunken: Color(0xFF0B0C0D),
    surface: Color(0xFF1C1D1F),
    surfaceWarm: Color(0xFF232426),
    border: Color(0xFF2E2F31),
    hairline: Color(0x14F2EFE8),
    textPrimary: Color(0xFFF2EFE8),
    textSecondary: Color(0xFFBDB9B0),
    textTertiary: Color(0xFF8F8C85),
    action: Color(0xFF2F7A61),
    actionPressed: Color(0xFF245C4A),
    onAction: Color(0xFFFFFFFF),
    accent: Color(0xFFE0AE62),
    accentPressed: Color(0xFFD49A45),
    onAccent: Color(0xFF111315),
    accentText: Color(0xFFE8BC78),
    accentTint: Color(0xFF3A2E1C),
    success: Color(0xFF6DB89A),
    successTint: Color(0xFF1F3A31),
    onSuccessTint: Color(0xFFB5E3CF),
    gentle: Color(0xFFE08A6E),
    gentleTint: Color(0xFF3D2620),
    onGentleTint: Color(0xFFF5C3B2),
    sage: Color(0xFF8A9B88),
    sand: Color(0xFF4A4535),
    danger: Color(0xFFE5806B),
    scrim: Color(0x99000000),
    shadow: Color(0xFF000000),
  );

  @override
  MwColors copyWith({Color? canvas, Color? surface, Color? action, Color? accent}) {
    return MwColors(
      canvas: canvas ?? this.canvas,
      sunken: sunken,
      surface: surface ?? this.surface,
      surfaceWarm: surfaceWarm,
      border: border,
      hairline: hairline,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      textTertiary: textTertiary,
      action: action ?? this.action,
      actionPressed: actionPressed,
      onAction: onAction,
      accent: accent ?? this.accent,
      accentPressed: accentPressed,
      onAccent: onAccent,
      accentText: accentText,
      accentTint: accentTint,
      success: success,
      successTint: successTint,
      onSuccessTint: onSuccessTint,
      gentle: gentle,
      gentleTint: gentleTint,
      onGentleTint: onGentleTint,
      sage: sage,
      sand: sand,
      danger: danger,
      scrim: scrim,
      shadow: shadow,
    );
  }

  @override
  MwColors lerp(MwColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return MwColors(
      canvas: l(canvas, other.canvas),
      sunken: l(sunken, other.sunken),
      surface: l(surface, other.surface),
      surfaceWarm: l(surfaceWarm, other.surfaceWarm),
      border: l(border, other.border),
      hairline: l(hairline, other.hairline),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textTertiary: l(textTertiary, other.textTertiary),
      action: l(action, other.action),
      actionPressed: l(actionPressed, other.actionPressed),
      onAction: l(onAction, other.onAction),
      accent: l(accent, other.accent),
      accentPressed: l(accentPressed, other.accentPressed),
      onAccent: l(onAccent, other.onAccent),
      accentText: l(accentText, other.accentText),
      accentTint: l(accentTint, other.accentTint),
      success: l(success, other.success),
      successTint: l(successTint, other.successTint),
      onSuccessTint: l(onSuccessTint, other.onSuccessTint),
      gentle: l(gentle, other.gentle),
      gentleTint: l(gentleTint, other.gentleTint),
      onGentleTint: l(onGentleTint, other.onGentleTint),
      sage: l(sage, other.sage),
      sand: l(sand, other.sand),
      danger: l(danger, other.danger),
      scrim: l(scrim, other.scrim),
      shadow: l(shadow, other.shadow),
    );
  }
}
