import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/formats.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/misc.dart';
import '../../core/widgets/status_tag.dart';
import '../../data/models/models.dart';
import '../../logic/app_state.dart';
import '../../logic/labels.dart';

/// Ligne de séance : heures, pastille, titre + sous-titre, tag de statut.
class SessionRow extends StatelessWidget {
  const SessionRow({super.key, required this.session, required this.app, required this.onTap});

  final Session session;
  final AppState app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final S = app.svc(s.svc);
    final sub = s.cls != null
        ? 'Succès Group · ${S.name}'
        : (s.isRattrapage ? 'Rattrapage · à domicile' : 'À domicile');
    return Tap(
      onTap: onTap,
      border: Border.all(color: AppColors.divider),
      constraints: const BoxConstraints(minHeight: 62),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fmt(s.start), style: AppText.heading(18, height: 1.1)),
                Text(
                  fmt(s.end),
                  style: AppText.heading(15, weight: FontWeight.w400, color: AppColors.neutral700, height: 1.1),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          CodeBadge(code: S.code, color: S.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(app.titleOf(s), style: AppText.body(15, weight: FontWeight.w500, height: 1.3)),
                Text(sub, style: AppText.body(13, color: AppColors.neutral700)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          StatusTag(tagOfSession(s)),
        ],
      ),
    );
  }
}
