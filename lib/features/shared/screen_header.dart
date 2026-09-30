import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/buttons.dart';

class HeaderBar extends StatelessWidget {
  const HeaderBar({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(12, 12, 12, 10)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: child,
    );
  }
}

class WeekHeader extends StatelessWidget {
  const WeekHeader({super.key, required this.kicker, required this.label, required this.onPrev, required this.onNext});

  final String kicker;
  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return HeaderBar(
      child: Row(
        children: [
          SquareIconButton(icon: AppIcons.chevronLeft, onPressed: onPrev, tooltip: 'Semaine précédente'),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              children: [
                Text(kicker.toUpperCase(), style: AppText.kicker, textAlign: TextAlign.center),
                Text(label, style: AppText.heading(24, height: 1.1), textAlign: TextAlign.center),
              ],
            ),
          ),
          const SizedBox(width: 6),
          SquareIconButton(icon: AppIcons.chevronRight, onPressed: onNext, tooltip: 'Semaine suivante'),
        ],
      ),
    );
  }
}

class FooterBar extends StatelessWidget {
  const FooterBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

class ScreenBody extends StatelessWidget {
  const ScreenBody({
    super.key,
    required this.children,
    this.gap = 24,
    this.padding = const EdgeInsets.fromLTRB(16, 18, 16, 24),
    this.controller,
  });

  final List<Widget> children;
  final double gap;
  final EdgeInsetsGeometry padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: controller,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) SizedBox(height: gap), children[i]],
        ],
      ),
    );
  }
}
