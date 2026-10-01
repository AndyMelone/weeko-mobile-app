import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'buttons.dart';
import 'inputs.dart';

/// Saisie d'un texte en bottom sheet (l'app n'utilise pas de popup).
/// Retourne le texte saisi (sans espaces autour), null si annulé ou vide.
Future<String?> showTextSheet(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String initial = '',
  String? hint,
}) async {
  final v = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(),
    builder: (_) => _TextSheet(title: title, confirmLabel: confirmLabel, initial: initial, hint: hint),
  );
  final t = v?.trim() ?? '';
  return t.isEmpty ? null : t;
}

class _TextSheet extends StatefulWidget {
  const _TextSheet({required this.title, required this.confirmLabel, required this.initial, this.hint});

  final String title;
  final String confirmLabel;
  final String initial;
  final String? hint;

  @override
  State<_TextSheet> createState() => _TextSheetState();
}

class _TextSheetState extends State<_TextSheet> {
  late final _ctrl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: AppText.heading(22)),
              const SizedBox(height: 12),
              AppTextField(controller: _ctrl, hint: widget.hint, autofocus: true, onChanged: (_) => setState(() {})),
              const SizedBox(height: 16),
              PrimaryButton(
                label: widget.confirmLabel,
                onPressed: _ctrl.text.trim().isEmpty ? null : () => Navigator.pop(context, _ctrl.text),
              ),
              const SizedBox(height: 8),
              GhostButton(label: 'Annuler', onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
      ),
    );
  }
}
