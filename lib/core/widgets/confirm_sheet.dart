import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'buttons.dart';

/// Confirmation en bottom sheet (l'app n'utilise pas de popup).
/// Retourne true si l'action est confirmée.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Annuler',
}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(),
    builder: (ctx) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: AppText.heading(22)),
            const SizedBox(height: 8),
            Text(message, style: AppText.body(15)),
            const SizedBox(height: 20),
            PrimaryButton(label: confirmLabel, onPressed: () => Navigator.pop(ctx, true)),
            const SizedBox(height: 8),
            SecondaryButton(label: cancelLabel, onPressed: () => Navigator.pop(ctx, false)),
          ],
        ),
      ),
    ),
  );
  return ok == true;
}
