import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'app_icon.dart';

class Tap extends StatelessWidget {
  const Tap({
    super.key,
    required this.onTap,
    required this.child,
    this.onLongPress,
    this.color = Colors.transparent,
    this.border,
    this.padding,
    this.constraints,
  });

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget child;
  final Color color;
  final BoxBorder? border;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const RoundedRectangleBorder(),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          constraints: constraints,
          padding: padding,
          decoration: BoxDecoration(border: border),
          child: child,
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 52,
    this.fontSize = 18,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final double fontSize;
  final AppIcons? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : .45,
      child: Tap(
        onTap: onPressed,
        color: AppColors.accent,
        constraints: BoxConstraints(minHeight: height),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[AppIcon(icon!, size: 18, color: AppColors.bg), const SizedBox(width: 6)],
              Text(label, style: AppText.heading(fontSize, color: AppColors.bg)),
            ],
          ),
        ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 44,
    this.fontSize = 15,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final double fontSize;
  final AppIcons? icon;

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onPressed,
      border: Border.all(color: AppColors.divider),
      constraints: BoxConstraints(minHeight: height),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[AppIcon(icon!, size: 16, color: AppColors.text), const SizedBox(width: 6)],
            Flexible(
              child: Text(label, style: AppText.heading(fontSize), textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}

class GhostButton extends StatelessWidget {
  const GhostButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onPressed,
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Center(
        widthFactor: 1,
        child: Text(label, style: AppText.heading(15, color: AppColors.accent)),
      ),
    );
  }
}

class SquareIconButton extends StatelessWidget {
  const SquareIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.iconSize = 20,
  });

  final AppIcons icon;
  final VoidCallback onPressed;
  final String tooltip;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tooltip,
      button: true,
      child: Tap(
        onTap: onPressed,
        border: Border.all(color: AppColors.divider),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: AppIcon(icon, size: iconSize, color: AppColors.text),
          ),
        ),
      ),
    );
  }
}
