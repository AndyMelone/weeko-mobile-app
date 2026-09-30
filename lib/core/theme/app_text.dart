import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typo : Barlow Condensed 600 (titres, heures), Barlow 400/500 (texte).
abstract final class AppText {
  static TextStyle heading(
    double size, {
    Color color = AppColors.text,
    FontWeight weight = FontWeight.w600,
    double? height,
    double letterSpacing = 0,
  }) => TextStyle(
    fontFamily: 'BarlowCondensed',
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );

  static TextStyle body(
    double size, {
    Color color = AppColors.text,
    FontWeight weight = FontWeight.w400,
    double? height,
    TextDecoration? decoration,
  }) => TextStyle(
    fontFamily: 'Barlow',
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    decoration: decoration,
    decorationColor: color,
  );

  /// Titre de section : 14px, uppercase, letter-spacing .08em, neutral-700.
  static TextStyle get section => heading(14, color: AppColors.neutral700, letterSpacing: 14 * .08);

  /// Kicker : 11px, uppercase, letter-spacing .1em, accent-700.
  static TextStyle get kicker => body(11, color: AppColors.accent700).copyWith(letterSpacing: 1.1);
}
