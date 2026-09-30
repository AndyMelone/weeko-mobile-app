import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/formats.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/blueprint.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/misc.dart';
import '../../data/api/api_client.dart';
import '../../data/demo_data.dart';
import '../../data/models/models.dart';
import '../../logic/app_state.dart';
import '../../logic/nav_state.dart';
import '../shared/screen_header.dart';

class PointerScreen extends StatefulWidget {
  const PointerScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<PointerScreen> createState() => _PointerScreenState();
}

class _PointerScreenState extends State<PointerScreen> {
  late PointerDraft _draft;

  late bool _chosen;
  final _motifCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>().sessionById(widget.sessionId)!;
    _draft = PointerDraft(missed: s.status == SessionStatus.manquee, who: s.who, motif: s.motif, redo: !s.noRedo);
    _chosen = s.status != SessionStatus.prevue;
    if (!motifs.contains(s.motif)) _motifCtrl.text = s.motif;
  }

  @override
  void dispose() {
    _motifCtrl.dispose();
    super.dispose();
  }

  void _set(PointerDraft d) => setState(() {
    _draft = d;
    _chosen = true;
  });

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final nav = context.read<NavState>();
    final s = app.sessionById(widget.sessionId)!;
    final S = app.svc(s.svc);
    final d = _draft;
    final due = s.dueId == null ? null : app.dues.where((u) => u.id == s.dueId).firstOrNull;

    final dueNote = !d.redo
        ? 'Aucune séance à rattraper ne sera créée. La séance reste dans l’historique comme manquée, sans rattrapage.'
        : s.isRattrapage
        ? 'Le rattrapage sera à recaser dans Rattrapages.'
        : 'Une séance à rattraper sera créée pour ${app.titleOf(s)}, à caser dans Rattrapages (cette semaine ou plus tard).';
    final canSave = _chosen && (!d.missed || d.who != null);

    return Column(
      children: [
        HeaderBar(
          child: Row(
            children: [
              SquareIconButton(icon: AppIcons.arrowLeft, onPressed: nav.closePointer, tooltip: 'Retour'),
              const SizedBox(width: 8),
              Text('Pointer la séance', style: AppText.heading(24)),
            ],
          ),
        ),
        Expanded(
          child: ScreenBody(
            gap: 22,
            children: [
              Blueprint(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CodeBadge(code: S.code, color: S.color, size: 48, fontSize: 17),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(app.titleOf(s), style: AppText.heading(22, height: 1.15)),
                          Text('${dayLong(s.week, s.day)} · ${range(s.start, s.end)}', style: AppText.body(15)),
                          Text(
                            s.cls != null ? 'Succès Group · ${S.name}' : 'À domicile',
                            style: AppText.body(13, color: AppColors.neutral700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (s.isRattrapage)
                Container(
                  color: AppColors.accent100,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Text(
                    'Séance de rattrapage${due != null ? ' (manquée ${due.from}${due.motif.isNotEmpty ? ', ${due.motif.toLowerCase()}' : ''})' : ''}. Une fois faite, la séance manquée passe à « rattrapée ».',
                    style: AppText.body(14, color: AppColors.accent800),
                  ),
                ),
              Section(
                title: 'Statut',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatusButton(
                          label: 'Faite',
                          icon: AppIcons.check,
                          selected: _chosen && !d.missed,
                          onTap: () => _set(d.copyWith(missed: false)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatusButton(
                          label: 'Manquée',
                          icon: AppIcons.x,
                          selected: _chosen && d.missed,
                          onTap: () => _set(d.copyWith(missed: true)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (_chosen && d.missed) ...[
                Section(
                  title: 'Qui était absent ?',
                  children: [
                    Segmented(
                      height: 52,
                      fontSize: 16,
                      options: [
                        SegOption(
                          label: 'Moi',
                          selected: d.who == Who.moi,
                          onTap: () => _set(d.copyWith(who: Who.moi)),
                        ),
                        SegOption(
                          label: s.cls != null ? 'La classe' : "L'élève",
                          selected: d.who == Who.eleve,
                          onTap: () => _set(d.copyWith(who: Who.eleve)),
                        ),
                      ],
                    ),
                  ],
                ),
                Section(
                  title: 'Rattrapage',
                  children: [
                    Segmented(
                      height: 52,
                      fontSize: 16,
                      options: [
                        SegOption(label: 'À rattraper', selected: d.redo, onTap: () => _set(d.copyWith(redo: true))),
                        SegOption(
                          label: 'Pas de rattrapage',
                          selected: !d.redo,
                          onTap: () => _set(d.copyWith(redo: false)),
                        ),
                      ],
                    ),
                  ],
                ),
                Section(
                  title: 'Motif (facultatif)',
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final m in motifs)
                          Tap(
                            onTap: () {
                              _motifCtrl.clear();
                              _set(d.copyWith(motif: m));
                            },
                            color: d.motif == m ? AppColors.accent : Colors.transparent,
                            border: Border.all(color: d.motif == m ? AppColors.accent : AppColors.divider),
                            constraints: const BoxConstraints(minHeight: 44),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(m, style: AppText.body(14, color: d.motif == m ? AppColors.bg : AppColors.text)),
                              ],
                            ),
                          ),
                      ],
                    ),
                    AppTextField(
                      controller: _motifCtrl,
                      hint: 'Autre motif…',
                      onChanged: (v) => _set(d.copyWith(motif: v)),
                    ),
                  ],
                ),
                DashedNote(child: Text(dueNote, style: AppText.body(14))),
              ],
            ],
          ),
        ),
        FooterBar(
          children: [
            PrimaryButton(
              label: 'Enregistrer',
              onPressed: canSave
                  ? () async {
                      try {
                        final msg = await app.savePointer(s.id, d);
                        nav.closePointer();
                        nav.showToast(msg);
                      } on ApiException catch (e) {
                        nav.showToast(e.message);
                      }
                    }
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({required this.label, required this.icon, required this.selected, required this.onTap});

  final String label;
  final AppIcons icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.bg : AppColors.text;
    return Tap(
      onTap: onTap,
      color: selected ? AppColors.accent : Colors.transparent,
      border: Border.all(color: selected ? AppColors.accent : AppColors.divider),
      constraints: const BoxConstraints(minHeight: 60),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(icon, color: fg),
            const SizedBox(width: 8),
            Text(label, style: AppText.heading(19, color: fg)),
          ],
        ),
      ),
    );
  }
}
