import 'package:flutter/material.dart';

abstract final class AppColors {
  static const bg = Color(0xFFF2F2F3);
  static const surface = Color(0xFFE9E9EA);
  static const text = Color(0xFF1D1F20);
  static const accent = Color(0xFF5980A6);

  static const divider = Color(0x291D1F20);

  /// Avertissement non bloquant (règle non respectée dans un aperçu modifié).
  static const warning = Color(0xFFA15C07);
  static const warningBg = Color(0xFFFBF1E3);

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

  static const shadowLg = [BoxShadow(color: Color(0x382B2B2D), blurRadius: 32, offset: Offset(0, 12))];
}

abstract final class ServiceColors {
  static const angeKra = Color(0xFF9B4630);
  static const adje = Color(0xFF337344);
  static const sondo = Color(0xFF814A8D);
  static const mamieAdjoua = Color(0xFF326893);
  static const niangon = Color(0xFF8A5F18);

  static const palette = [
    Color(0xFF007475),
    Color(0xFF9C3E60),
    Color(0xFF676815),
    Color(0xFF5759A6),
    Color(0xFF925019),
    Color(0xFF00755A),
  ];
}
