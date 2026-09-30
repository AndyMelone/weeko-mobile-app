import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Pastille carrée couleur + code 2 lettres.
class CodeBadge extends StatelessWidget {
  const CodeBadge({super.key, required this.code, required this.color, this.size = 36, this.fontSize = 14});

  final String code;
  final Color color;
  final double size;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: color,
      alignment: Alignment.center,
      child: Text(
        code,
        style: AppText.heading(fontSize, color: Colors.white, letterSpacing: fontSize * .04),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.fontSize = 14});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: AppText.heading(fontSize, color: AppColors.neutral700, letterSpacing: fontSize * .08),
  );
}

class Section extends StatelessWidget {
  const Section({super.key, required this.title, required this.children, this.gap = 8});

  final String title;
  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(title),
        for (final c in children) ...[SizedBox(height: gap), c],
      ],
    );
  }
}

/// Note en cadre pointillé.
class DashedNote extends StatelessWidget {
  const DashedNote({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    this.color = AppColors.neutral500,
    this.minHeight,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: DashedBorderPainter(color: color),
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight ?? 0),
        padding: padding,
        alignment: minHeight != null ? Alignment.centerLeft : null,
        child: child,
      ),
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  DashedBorderPainter({required this.color, this.dash = 3, this.gap = 3});

  final Color color;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    void line(Offset a, Offset b) {
      final len = (b - a).distance;
      final dir = (b - a) / len;
      for (double d = 0; d < len; d += dash + gap) {
        canvas.drawLine(a + dir * d, a + dir * (d + dash).clamp(0, len), p);
      }
    }

    const h = .5;
    line(const Offset(h, h), Offset(size.width - h, h));
    line(Offset(size.width - h, h), Offset(size.width - h, size.height - h));
    line(Offset(size.width - h, size.height - h), Offset(h, size.height - h));
    line(Offset(h, size.height - h), const Offset(h, h));
  }

  @override
  bool shouldRepaint(DashedBorderPainter old) => old.color != color;
}

/// Divise une liste de widgets par un trait (bordure basse).
class Bordered extends StatelessWidget {
  const Bordered({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: AppColors.divider)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++)
            Container(
              decoration: i < children.length - 1
                  ? const BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppColors.divider)),
                    )
                  : null,
              child: children[i],
            ),
        ],
      ),
    );
  }
}
