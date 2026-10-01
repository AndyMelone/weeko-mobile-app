import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/confirm_sheet.dart';
import '../../core/widgets/misc.dart';
import '../../core/widgets/text_sheet.dart';
import '../../data/api/api_client.dart';
import '../../data/models/models.dart';
import '../../logic/app_state.dart';
import '../../logic/nav_state.dart';
import '../shared/screen_header.dart';

/// Réglages Succès Group : sites et classes. Premier choix de l'onglet Élèves.
class SitesPanel extends StatelessWidget {
  const SitesPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final nav = context.read<NavState>();

    /// Lance une modification et affiche le toast (ou l'erreur).
    Future<void> run(Future<void> Function() call, String done) async {
      try {
        await call();
        nav.showToast(done);
      } on ApiException catch (e) {
        nav.showToast(e.message);
      }
    }

    Future<void> addSite() async {
      final name = await showTextSheet(context, title: 'Nouveau site', confirmLabel: 'Ajouter', hint: 'Nom du site');
      if (name != null) await run(() => app.addSite(name), 'Site $name ajouté');
    }

    Future<void> siteActions(Service S) async {
      final action = await _actionsSheet(context, S.name);
      if (!context.mounted) return;
      if (action == 'rename') {
        final name = await showTextSheet(
          context,
          title: 'Renommer le site',
          confirmLabel: 'Enregistrer',
          initial: S.name,
        );
        if (name != null && name != S.name) await run(() => app.renameSite(S.id, name), 'Site renommé');
      } else if (action == 'delete') {
        final ok = await showConfirmSheet(
          context,
          title: 'Supprimer ${S.name} ?',
          message: '${S.name} et ses classes n’apparaîtront plus dans le planning. L’historique est conservé.',
          confirmLabel: 'Supprimer',
        );
        if (ok) await run(() => app.deleteSite(S.id), '${S.name} supprimé');
      }
    }

    Future<void> addClass(Service S) async {
      final name = await showTextSheet(
        context,
        title: 'Nouvelle classe · ${S.name}',
        confirmLabel: 'Ajouter',
        hint: 'Ex. Terminale D',
      );
      if (name != null) await run(() => app.addClass(S.id, name), 'Classe $name ajoutée');
    }

    Future<void> classActions(Service S, SchoolClass c) async {
      final action = await _actionsSheet(context, '${c.name} · ${S.name}');
      if (!context.mounted) return;
      if (action == 'rename') {
        final name = await showTextSheet(
          context,
          title: 'Renommer la classe',
          confirmLabel: 'Enregistrer',
          initial: c.name,
        );
        if (name != null && name != c.name) await run(() => app.renameClass(c.id, name), 'Classe renommée');
      } else if (action == 'delete') {
        final ok = await showConfirmSheet(
          context,
          title: 'Supprimer ${c.name} ?',
          message: '${c.name} (${S.name}) n’apparaîtra plus dans le planning. L’historique est conservé.',
          confirmLabel: 'Supprimer',
        );
        if (ok) await run(() => app.deleteClass(c.id), '${c.name} supprimée');
      }
    }

    final sites = app.sites;
    return Column(
      children: [
        Expanded(
          child: ScreenBody(
            children: [
              if (sites.isEmpty)
                Text('Aucun site. Ajoutez-en un ci-dessous.', style: AppText.body(15, color: AppColors.neutral700)),
              for (final S in sites)
                Section(
                  title: S.name,
                  children: [
                    Bordered(
                      children: [
                        _Row(
                          leading: CodeBadge(code: S.code, color: S.color, size: 32, fontSize: 13),
                          title: S.name,
                          subtitle: 'Site · toucher pour renommer ou supprimer',
                          onTap: () => siteActions(S),
                        ),
                        for (final c in app.classesOf(S.id))
                          _Row(leading: const SizedBox(width: 32), title: c.name, onTap: () => classActions(S, c)),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GhostButton(label: '+ Ajouter une classe', onPressed: () => addClass(S)),
                    ),
                  ],
                ),
            ],
          ),
        ),
        FooterBar(
          children: [PrimaryButton(label: 'Ajouter un site', icon: AppIcons.plus, onPressed: addSite)],
        ),
      ],
    );
  }
}

/// Feuille d'actions : Renommer / Supprimer. Retourne 'rename', 'delete' ou null.
Future<String?> _actionsSheet(BuildContext context, String title) => showModalBottomSheet<String>(
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
          const SizedBox(height: 16),
          PrimaryButton(label: 'Renommer', onPressed: () => Navigator.pop(ctx, 'rename')),
          const SizedBox(height: 8),
          SecondaryButton(label: 'Supprimer', icon: AppIcons.x, onPressed: () => Navigator.pop(ctx, 'delete')),
          const SizedBox(height: 8),
          GhostButton(label: 'Annuler', onPressed: () => Navigator.pop(ctx)),
        ],
      ),
    ),
  ),
);

class _Row extends StatelessWidget {
  const _Row({required this.leading, required this.title, this.subtitle, required this.onTap});

  final Widget leading;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onTap,
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.fromLTRB(12, 6, 10, 6),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.body(15, weight: FontWeight.w500)),
                if (subtitle != null) Text(subtitle!, style: AppText.body(13, color: AppColors.neutral700)),
              ],
            ),
          ),
          const AppIcon(AppIcons.chevronRight, size: 18, color: AppColors.neutral600),
        ],
      ),
    );
  }
}
