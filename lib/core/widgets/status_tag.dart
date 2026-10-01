import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

enum TagKind {
  prevue('Prévue', Colors.transparent, AppColors.neutral800, AppColors.neutral400),
  aPointer('À pointer', AppColors.warningBg, AppColors.warning, AppColors.warning),
  rattrapage('Rattrapage', Colors.transparent, AppColors.accent800, AppColors.accent600),
  faite('Faite', AppColors.accent100, AppColors.accent800, AppColors.accent300),
  manquee('Manquée', AppColors.neutral900, Colors.white, AppColors.neutral900),
  sansRattrapage('Manquée · sans rattrapage', Colors.transparent, AppColors.neutral800, AppColors.neutral800),
  rattrapee('Rattrapée', AppColors.accent700, Colors.white, AppColors.accent700),
  due('À rattraper', AppColors.neutral900, Colors.white, AppColors.neutral900),
  nonPlacee('Non placée', AppColors.neutral900, Colors.white, AppColors.neutral900),
  casee('Placée', AppColors.accent100, AppColors.accent800, AppColors.accent300);

  const TagKind(this.label, this.bg, this.fg, this.border);

  final String label;
  final Color bg;
  final Color fg;
  final Color border;
}

class StatusTag extends StatelessWidget {
  const StatusTag(this.kind, {super.key, this.count});

  final TagKind kind;

  /// Nombre affiché devant le libellé (ex. « 2 à pointer »).
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: kind.bg,
        border: Border.all(color: kind.border),
      ),
      child: Text(
        count == null ? kind.label : '$count ${kind.label.toLowerCase()}',
        style: AppText.body(11, color: kind.fg, weight: FontWeight.w500).copyWith(letterSpacing: .22),
      ),
    );
  }
}
