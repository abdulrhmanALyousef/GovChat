import 'package:flutter/material.dart';

class AppColors extends ThemeExtension<AppColors> {
  // ── Fixed colors (same in every theme) ──
  static const Color primaryColor = Color(0xFF4ADE80);
  static const Color gradientStart = Color(0xFF4BE277);
  static const Color gradientEnd = Color(0xFF22C55E);
  static const Color inputFocusBorder = Color(0xFF4ADE80);
  static const Color buttonBackground = Color(0xFF4ADE80);
  static const Color buttonText = Color(0xFF0A0F1A);
  static const Color accentLine = Color(0xFF4ADE80);
  static const Color error = Color(0xFFEF4444);

  // ── Theme-dependent instance fields ──
  final Color scaffoldBackground;
  final Color cardBackground;
  final Color sectionBackground;
  final Color ruleBackground;
  final Color bottomNavBackground;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTitle;
  final Color textMuted;
  final Color textSubtitle;
  final Color hintText;
  final Color iconMuted;
  final Color inputFill;
  final Color inputBorder;
  final Color navUnselected;
  final Color shadowColor;
  final Color shadowDark;
  final Color formBorder;

  const AppColors({
    required this.scaffoldBackground,
    required this.cardBackground,
    required this.sectionBackground,
    required this.ruleBackground,
    required this.bottomNavBackground,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTitle,
    required this.textMuted,
    required this.textSubtitle,
    required this.hintText,
    required this.iconMuted,
    required this.inputFill,
    required this.inputBorder,
    required this.navUnselected,
    required this.shadowColor,
    required this.shadowDark,
    required this.formBorder,
  });

  // ── Dark theme ──
  static const AppColors dark = AppColors(
    scaffoldBackground: Color(0xFF0B1326),
    cardBackground: Color(0xFF1A2035),
    sectionBackground: Color(0xFF1E2640),
    ruleBackground: Color(0xFF171F33),
    bottomNavBackground: Color(0xFF131929),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF8A95A3),
    textTitle: Color(0xFFDAE2FD),
    textMuted: Color(0xFF94A3B8),
    textSubtitle: Color(0xFFBCCBB9),
    hintText: Color(0xFF64748B),
    iconMuted: Color(0xFF4A5568),
    inputFill: Color(0x802D3449),
    inputBorder: Color(0xFF2A3550),
    navUnselected: Color(0xFF4A5568),
    shadowColor: Color(0x40000000),
    shadowDark: Color(0x4D000000),
    formBorder: Color(0x1A3D4A3D),
  );

  // ── Light theme ──
  static const AppColors light = AppColors(
    scaffoldBackground: Color(0xFFF4F6FB),
    cardBackground: Color(0xFFFFFFFF),
    sectionBackground: Color(0xFFF1F5F9),
    ruleBackground: Color(0xFFE8EEF8),
    bottomNavBackground: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF0A1628),
    textSecondary: Color(0xFF475569),
    textTitle: Color(0xFF0D1F3C),
    textMuted: Color(0xFF64748B),
    textSubtitle: Color(0xFF4A5568),
    hintText: Color(0xFF94A3B8),
    iconMuted: Color(0xFFCBD5E1),
    inputFill: Color(0xFFF8FAFC),
    inputBorder: Color(0xFFCBD5E1),
    navUnselected: Color(0xFF94A3B8),
    shadowColor: Color(0x14000000),
    shadowDark: Color(0x1F000000),
    formBorder: Color(0xFFE2E8F0),
  );

  @override
  AppColors copyWith({
    Color? scaffoldBackground,
    Color? cardBackground,
    Color? sectionBackground,
    Color? ruleBackground,
    Color? bottomNavBackground,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTitle,
    Color? textMuted,
    Color? textSubtitle,
    Color? hintText,
    Color? iconMuted,
    Color? inputFill,
    Color? inputBorder,
    Color? navUnselected,
    Color? shadowColor,
    Color? shadowDark,
    Color? formBorder,
  }) {
    return AppColors(
      scaffoldBackground: scaffoldBackground ?? this.scaffoldBackground,
      cardBackground: cardBackground ?? this.cardBackground,
      sectionBackground: sectionBackground ?? this.sectionBackground,
      ruleBackground: ruleBackground ?? this.ruleBackground,
      bottomNavBackground: bottomNavBackground ?? this.bottomNavBackground,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTitle: textTitle ?? this.textTitle,
      textMuted: textMuted ?? this.textMuted,
      textSubtitle: textSubtitle ?? this.textSubtitle,
      hintText: hintText ?? this.hintText,
      iconMuted: iconMuted ?? this.iconMuted,
      inputFill: inputFill ?? this.inputFill,
      inputBorder: inputBorder ?? this.inputBorder,
      navUnselected: navUnselected ?? this.navUnselected,
      shadowColor: shadowColor ?? this.shadowColor,
      shadowDark: shadowDark ?? this.shadowDark,
      formBorder: formBorder ?? this.formBorder,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      scaffoldBackground:
          Color.lerp(scaffoldBackground, other.scaffoldBackground, t)!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      sectionBackground:
          Color.lerp(sectionBackground, other.sectionBackground, t)!,
      ruleBackground: Color.lerp(ruleBackground, other.ruleBackground, t)!,
      bottomNavBackground:
          Color.lerp(bottomNavBackground, other.bottomNavBackground, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTitle: Color.lerp(textTitle, other.textTitle, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textSubtitle: Color.lerp(textSubtitle, other.textSubtitle, t)!,
      hintText: Color.lerp(hintText, other.hintText, t)!,
      iconMuted: Color.lerp(iconMuted, other.iconMuted, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
      navUnselected: Color.lerp(navUnselected, other.navUnselected, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
      shadowDark: Color.lerp(shadowDark, other.shadowDark, t)!,
      formBorder: Color.lerp(formBorder, other.formBorder, t)!,
    );
  }
}

/// Shortcut: `context.colors.scaffoldBackground`
extension AppColorsX on BuildContext {
  // Falls back based on current brightness when no extension is registered
  // (e.g. during theme transitions, dialog overlays, or widget builds that
  // happen before MaterialApp applies its theme).
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ??
      (Theme.of(this).brightness == Brightness.light
          ? AppColors.light
          : AppColors.dark);
}
