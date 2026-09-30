import 'package:flutter/material.dart';

/// Tokens du design system « Industry » (voir handoff `_ds/.../styles.css`).
abstract final class AppColors {
  static const bg = Color(0xFFF2F2F3);
  static const surface = Color(0xFFE9E9EA);
  static const text = Color(0xFF1D1F20);
  static const accent = Color(0xFF5980A6);

  /// `--color-divider` : texte à 16 %.
  static const divider = Color(0x291D1F20);

  static const neutral200 = Color(0xFFE7E7EA);
  static const neutral300 = Color(0xFFD4D4D7);
  static const neutral400 = Color(0xFFB7B7BA);
  static const neutral500 = Color(0xFF98989B);
  static const neutral600 = Color(0xFF7A7A7D);
  static const neutral700 = Color(0xFF5D5D60);
  static const neutral800 = Color(0xFF424244);
  static const neutral900 = Color(0xFF2B2B2D);

  static const accent100 = Color(0xFFEEF6FF);
  static const accent300 = Color(0xFFB5D9FD);
  static const accent600 = Color(0xFF597EA3);
  static const accent700 = Color(0xFF416180);
  static const accent800 = Color(0xFF2C455D);
  static const accent900 = Color(0xFF1D2D3D);

  /// Ombre `--shadow-lg` (toast uniquement).
  static const shadowLg = [BoxShadow(color: Color(0x382B2B2D), blurRadius: 32, offset: Offset(0, 12))];
}

/// Couleurs de service (élèves et sites), OKLCH L≈0.5 converties en sRGB.
abstract final class ServiceColors {
  static const angeKra = Color(0xFF9B4630); // oklch(0.5 0.12 35)
  static const adje = Color(0xFF337344); // oklch(0.5 0.1 150)
  static const sondo = Color(0xFF814A8D); // oklch(0.5 0.12 320)
  static const mamieAdjoua = Color(0xFF326893); // oklch(0.5 0.09 245)
  static const niangon = Color(0xFF8A5F18); // oklch(0.52 0.1 75)

  /// Palette des nouveaux élèves : H ∈ 195, 0, 110, 280, 55, 170.
  static const palette = [
    Color(0xFF007475),
    Color(0xFF9C3E60),
    Color(0xFF676815),
    Color(0xFF5759A6),
    Color(0xFF925019),
    Color(0xFF00755A),
  ];
}
