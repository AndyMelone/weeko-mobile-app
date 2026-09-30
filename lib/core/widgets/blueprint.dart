import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Carte « plan technique » : bordure fine.
class Blueprint extends StatelessWidget {
  const Blueprint({super.key, required this.child, this.padding, this.color, this.borderColor = AppColors.divider});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}
