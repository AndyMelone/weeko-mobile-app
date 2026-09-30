import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/formats.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/blueprint.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/confirm_sheet.dart';
import '../../core/widgets/misc.dart';
import '../../core/widgets/status_tag.dart';
import '../../data/api/api_client.dart';
import '../../data/models/models.dart';
import '../../logic/app_state.dart';
import '../../logic/labels.dart';
import '../../logic/nav_state.dart';
import '../shared/screen_header.dart';
import 'add_student_form.dart';

class EleveScreen extends StatelessWidget {
  const EleveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final nav = context.watch<NavState>();

    return Column(
      children: [
        HeaderBar(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final id in app.students) ...[
                        _StudentChip(
                          service: app.svc(id),
                          selected: id == nav.studentId && !nav.addingStudent,
                          onTap: () => nav.selectStudent(id),
                          onLongPress: () {
                            HapticFeedback.mediumImpact();
                            _confirmDelete(context, app, nav, app.svc(id));
                          },
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Semantics(
                label: 'Ajouter un élève',
                button: true,
                child: CustomPaint(
                  foregroundPainter: DashedBorderPainter(color: AppColors.accent600),
                  child: Tap(
                    onTap: () => nav.setAdding(true),
                    color: nav.addingStudent ? AppColors.accent100 : Colors.transparent,
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(child: AppIcon(AppIcons.plus, color: AppColors.accent800)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: nav.addingStudent
              ? AddStudentForm(
                  onCancel: () => nav.setAdding(false),
                  onSave: (form) async {
                    try {
                      final id = await app.addStudent(form);
                      nav.selectStudent(id);
                      nav.showToast('${form.name.trim()} ajouté · placé à la prochaine génération');
                    } on ApiException catch (e) {
                      nav.showToast(e.message);
                    }
                  },
                )
              : app.students.isEmpty
              ? Center(
                  child: Text(
                    'Aucun élève. Ajoutez-en un avec +.',
                    style: AppText.body(15, color: AppColors.neutral700),
                  ),
                )
              : _Fiche(
                  app: app,
                  nav: nav,
                  id: app.students.contains(nav.studentId) ? nav.studentId : app.students.first,
                ),
        ),
      ],
    );
  }
}

Future<void> _confirmDelete(BuildContext context, AppState app, NavState nav, Service S) async {
  final ok = await showConfirmSheet(
    context,
    title: 'Supprimer ${S.name} ?',
    message: '${S.first} n’apparaîtra plus dans le planning ni dans les rattrapages. Son historique est conservé.',
    confirmLabel: 'Supprimer',
  );
  if (!ok) return;
  try {
    await app.deleteStudent(S.id);
    if (app.students.isNotEmpty) nav.selectStudent(app.students.first);
    nav.showToast('${S.name} supprimé');
  } on ApiException catch (e) {
    nav.showToast(e.message);
  }
}

class _StudentChip extends StatelessWidget {
  const _StudentChip({required this.service, required this.selected, required this.onTap, required this.onLongPress});

  final Service service;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onTap,
      onLongPress: onLongPress,
      color: selected ? AppColors.neutral900 : Colors.transparent,
      border: Border.all(color: AppColors.divider),
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, color: service.color),
          const SizedBox(width: 6),
          Text(service.name, style: AppText.body(15, color: selected ? Colors.white : AppColors.text)),
        ],
      ),
    );
  }
}

class _Fiche extends StatelessWidget {
  const _Fiche({required this.app, required this.nav, required this.id});

  final AppState app;
  final NavState nav;
  final String id;

  @override
  Widget build(BuildContext context) {
    final S = app.svc(id);
    final mine = app.week(0).where((s) => s.svc == id).toList()
      ..sort((a, b) => a.day != b.day ? a.day - b.day : a.start - b.start);
    final myDues = app.dues.where((u) => u.svc == id && !u.done).toList();

    final hist = <({String date, String time, String sub, TagKind tag})>[
      for (final s in mine.where((s) => s.status != SessionStatus.prevue).toList().reversed)
        (
          date: '${dayNamesShort[s.day]} ${dateOf(0, s.day).day} oct.',
          time: range(s.start, s.end),
          sub: s.status == SessionStatus.manquee
              ? '${s.who == Who.moi ? 'Moi absent' : 'Élève absent'}${s.motif.isNotEmpty ? ' · ${s.motif.toLowerCase()}' : ''}${s.noRedo ? ' · pas de rattrapage' : ''}'
              : (s.isRattrapage ? 'Rattrapage' : 'Séance'),
          tag: tagOfSession(s),
        ),
      for (final h in app.history[id] ?? const <HistoryEntry>[])
        (date: h.date, time: h.time, sub: h.motif ?? 'Séance', tag: tagOfStatus(h.status)),
    ];

    final msg = app.programmeOf(id, 0);

    return ScreenBody(
      children: [
        Row(
          children: [
            CodeBadge(code: S.code, color: S.color, size: 60, fontSize: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(S.name, style: AppText.heading(30, height: 1.05)),
                  Text(app.ruleOf(S), style: AppText.body(14)),
                  Text('Parent · ${S.phoneLabel}', style: AppText.body(13, color: AppColors.neutral700)),
                ],
              ),
            ),
          ],
        ),
        Section(
          title: 'Cette semaine',
          children: [
            for (final s in mine)
              Tap(
                onTap: () => nav.openPointer(s.id),
                border: Border.all(color: AppColors.divider),
                constraints: const BoxConstraints(minHeight: 56),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dayLong(0, s.day), style: AppText.body(15, weight: FontWeight.w500)),
                          Text(range(s.start, s.end), style: AppText.heading(17)),
                        ],
                      ),
                    ),
                    StatusTag(tagOfSession(s)),
                  ],
                ),
              ),
            if (mine.isEmpty)
              Text('Pas de séance cette semaine.', style: AppText.body(14, color: AppColors.neutral700)),
          ],
        ),
        Section(
          title: 'Séances à rattraper',
          children: [
            for (final u in myDues)
              CustomPaint(
                foregroundPainter: DashedBorderPainter(color: AppColors.neutral500),
                child: Tap(
                  onTap: () => nav.go(AppScreen.rattrapages),
                  constraints: const BoxConstraints(minHeight: 56),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Manquée ${u.from} · ${app.whoLabel(u)}', style: AppText.body(15, weight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(_placedLabel(u), style: AppText.body(13, color: AppColors.accent800)),
                    ],
                  ),
                ),
              ),
            if (myDues.isEmpty)
              Text('Aucune séance à rattraper.', style: AppText.body(14, color: AppColors.neutral700)),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionTitle('Historique'),
            const SizedBox(height: 8),
            _History(key: ValueKey(id), entries: hist),
          ],
        ),
        Section(
          title: 'Programme à envoyer',
          children: [
            Stack(
              children: [
                Blueprint(
                  padding: const EdgeInsets.fromLTRB(14, 14, 48, 14),
                  child: Text(msg, style: AppText.body(15, height: 1.5)),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    tooltip: 'Copier le programme',
                    icon: const AppIcon(AppIcons.copy, color: AppColors.accent800),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: msg));
                      nav.showToast('Programme copié');
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  String _placedLabel(Due u) {
    final ps = app.sessionById(u.placedSession);
    return ps != null ? 'Casée ${dayShort(ps.week, ps.day)} · ${range(ps.start, ps.end)}' : 'À caser';
  }
}

class _History extends StatefulWidget {
  const _History({super.key, required this.entries});

  final List<({String date, String time, String sub, TagKind tag})> entries;

  @override
  State<_History> createState() => _HistoryState();
}

class _HistoryState extends State<_History> {
  static const _preview = 3;
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    final shown = _all ? entries : entries.take(_preview).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (entries.isEmpty) Text('Aucune séance passée.', style: AppText.body(14, color: AppColors.neutral700)),
        for (final h in shown)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 9),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${h.date} · ${h.time}', style: AppText.body(15)),
                      Text(h.sub, style: AppText.body(13, color: AppColors.neutral700)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                StatusTag(h.tag),
              ],
            ),
          ),
        if (entries.length > _preview)
          GhostButton(
            label: _all ? 'Voir moins' : 'Voir plus (${entries.length - _preview})',
            onPressed: () => setState(() => _all = !_all),
          ),
      ],
    );
  }
}
