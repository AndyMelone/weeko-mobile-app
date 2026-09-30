import 'package:flutter/material.dart';

import 'app_colors.dart';

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Barlow',
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      surface: AppColors.bg,
    ).copyWith(primary: AppColors.accent, onPrimary: AppColors.bg, onSurface: AppColors.text),
    splashFactory: NoSplash.splashFactory,
    highlightColor: AppColors.neutral300,
    hoverColor: AppColors.neutral200,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    timePickerTheme: const TimePickerThemeData(
      backgroundColor: AppColors.bg,
      shape: RoundedRectangleBorder(),
      hourMinuteShape: RoundedRectangleBorder(),
      dayPeriodShape: RoundedRectangleBorder(),
    ),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: AppColors.accent),
  );
}
