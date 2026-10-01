import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/formats.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/misc.dart';
import '../../data/api/api_client.dart';
import '../../data/models/models.dart';
import '../../logic/app_state.dart';
import '../../logic/nav_state.dart';
import '../shared/screen_header.dart';
import 'generation_sheet.dart';

class PreparerScreen extends StatelessWidget {
  const PreparerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final nav = context.watch<NavState>();
    final w = nav.prepWeek;
    final prep = app.prepOf(w);
    final kicker = switch (w - currentWeek) {
      0 => 'En cours',
      1 => 'La semaine prochaine',
      final n when n > 1 => 'Dans $n semaines',
      _ => 'Passée',
    };
    void edit(void Function(WeekPrep p) fn) => app.updatePrep(w, fn);
    final openDues = app.dues.where((u) => !u.done).toList();

    return Column(
      children: [
        WeekHeader(
          kicker: kicker,
          label: weekRange(w),
          onPrev: () => nav.setPrepWeek(w - 1),
          onNext: () => nav.setPrepWeek(w + 1),
        ),
        Expanded(
          child: ScreenBody(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Section(
                title: 'Fin du travail',
                children: [
                  Bordered(
                    children: [
                      for (var d = 0; d < 5; d++)
                        _OffRow(
                          label: '${dayNamesLong[d]} ${dateOf(w, d).day}',
                          value: prep.off[d],
                          onChanged: (v) => edit((p) => p.off[d] = v),
                          fromWork: app.fromWork,
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Compter les trajets', style: AppText.body(15, weight: FontWeight.w500)),
                      ),
                      Switch.adaptive(
                        value: app.travelEnabled,
                        activeTrackColor: AppColors.accent,
                        onChanged: (v) async {
                          try {
                            await app.setTravel(v);
                            nav.showToast(v ? 'Trajets comptés' : 'Trajets non comptés · séances bout à bout');
                          } on ApiException catch (e) {
                            nav.showToast(e.message);
                          }
                        },
                      ),
                    ],
                  ),
                  Text(
                    app.travelEnabled
                        ? '30 min de trajet vers un élève ou un site, 10 min entre deux élèves, rien après 21h30.'
                        : 'Trajets non comptés : les séances peuvent s’enchaîner, rien après 21h30.',
                    style: AppText.body(13, color: AppColors.neutral700),
                  ),
                  if (app.tutorUnavailable.isNotEmpty)
                    Text(
                      'Tes indisponibilités : ${app.tutorUnavailable.map((b) => '${dayNamesLower[b.day]} ${b.label}').join(', ')}.',
                      style: AppText.body(13, color: AppColors.neutral700),
                    ),
                ],
              ),
              Section(
                title: 'Séances Succès Group cette semaine',
                children: [
                  Bordered(
                    children: [
                      for (final c in app.classes.values)
                        _ClassTimes(
                          site: app.svc(c.siteId),
                          name: c.name,
                          times: prep.times[c.id],
                          autoCount: prep.counts[c.id] ?? 0,
                          onChanged: (ts) => edit((p) => p.times[c.id] = ts),
                        ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GhostButton(label: 'Gérer les sites et classes', onPressed: nav.openSites),
                  ),
                ],
              ),
              Section(
                title: 'Séances déjà décidées',
                children: [
                  for (final s in app.decided)
                    Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(border: Border.all(color: AppColors.divider)),
                      child: Row(
                        children: [
                          CodeBadge(code: app.svc(s.svc).code, color: app.svc(s.svc).color, size: 28, fontSize: 12),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${app.titleOf(s)}${s.cls != null ? ' · ${app.svc(s.svc).name}' : ''}',
                              style: AppText.body(15),
                            ),
                          ),
                          Text('${dayNamesShort[s.day]} ${range(s.start, s.end)}', style: AppText.heading(16)),
                        ],
                      ),
                    ),
                ],
              ),
              Section(
                title: 'Changements cette semaine',
                children: [
                  for (final k in app.students)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(border: Border.all(color: AppColors.divider)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              CodeBadge(code: app.svc(k).code, color: app.svc(k).color, size: 24, fontSize: 11),
                              const SizedBox(width: 8),
                              Text(app.svc(k).name, style: AppText.body(15, weight: FontWeight.w500)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Segmented(
                            options: [
                              for (final (v, l) in const [
                                (WeekChange.normal, 'Normal'),
                                (WeekChange.une, '1 séance'),
                                (WeekChange.absent, 'Absent'),
                              ])
                                SegOption(
                                  label: l,
                                  selected: (prep.changes[k] ?? WeekChange.normal) == v,
                                  onTap: () => edit((p) => p.changes[k] = v),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              Section(
                title: 'Séances à rattraper',
                children: [
                  for (final u in openDues)
                    _CatchupRow(
                      app: app,
                      due: u,
                      on: prep.include[u.id] != false,
                      onToggle: () => edit((p) => p.include[u.id] = p.include[u.id] == false),
                    ),
                  if (openDues.isEmpty)
                    Text('Aucune séance à rattraper.', style: AppText.body(14, color: AppColors.neutral700)),
                ],
              ),
            ],
          ),
        ),
        FooterBar(
          children: [
            if (app.generated.contains(w)) ...[
              Text(
                'Déjà généré : regénérer remplace les séances prévues.',
                textAlign: TextAlign.center,
                style: AppText.body(13, color: AppColors.neutral700),
              ),
              const SizedBox(height: 6),
            ],
            PrimaryButton(
              label: 'Générer le planning',
              onPressed: () async {
                final ({String message, List<Session> sessions}) draft;
                try {
                  draft = await app.preview(w);
                } on ApiException catch (e) {
                  nav.showToast(e.message);
                  return;
                }
                if (!context.mounted) return;
                final ok = await showGenerationSheet(
                  context,
                  app: app,
                  week: w,
                  message: draft.message,
                  sessions: draft.sessions,
                );
                if (ok != true) return;
                try {
                  final msg = await app.generate(w);
                  nav.setWeek(w);
                  nav.go(AppScreen.semaine);
                  nav.showToast('Planning validé · $msg');
                } on ApiException catch (e) {
                  nav.showToast(e.message);
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _OffRow extends StatelessWidget {
  const _OffRow({required this.label, required this.value, required this.onChanged, required this.fromWork});

  final int fromWork;

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final o = parseTime(value);
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: AppText.body(15, weight: FontWeight.w500)),
          ),
          if (o != null && fromWork > 0)
            Text('dispo ${fmt(o + fromWork)}', style: AppText.body(12, color: AppColors.neutral700)),
          const SizedBox(width: 8),
          TimeField(value: value, onChanged: onChanged, width: 112),
        ],
      ),
    );
  }
}

class _ClassTimes extends StatelessWidget {
  const _ClassTimes({
    required this.site,
    required this.name,
    required this.times,
    required this.autoCount,
    required this.onChanged,
  });

  final Service site;
  final String name;

  final List<ClassTime>? times;
  final int autoCount;
  final ValueChanged<List<ClassTime>> onChanged;

  static const _maxPerWeek = 7;

  ClassTime _next(List<ClassTime> ts) {
    final d = ts.isEmpty ? 0 : (ts.last.day + 1) % 7;
    return d < 5 ? (day: d, start: 1080, end: 1230) : (day: d, start: 480, end: 720);
  }

  void _set(List<ClassTime> ts, int i, ClassTime t) =>
      onChanged([for (var j = 0; j < ts.length; j++) j == i ? t : ts[j]]);

  Future<void> _pickDay(BuildContext context, List<ClassTime> ts, int i) async {
    final d = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(),
      builder: (_) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var d = 0; d < 7; d++)
              Tap(
                onTap: () => Navigator.pop(context, d),
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    dayNamesLong[d],
                    style: AppText.body(16, weight: d == ts[i].day ? FontWeight.w600 : FontWeight.w400),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (d != null) _set(ts, i, (day: d, start: ts[i].start, end: ts[i].end));
  }

  @override
  Widget build(BuildContext context) {
    final ts = times ?? const <ClassTime>[];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CodeBadge(code: site.code, color: site.color, size: 32, fontSize: 13),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppText.body(15, weight: FontWeight.w500)),
                    Text(site.name, style: AppText.body(13, color: AppColors.neutral700)),
                  ],
                ),
              ),
              if (ts.length < _maxPerWeek)
                SquareIconButton(
                  icon: AppIcons.plus,
                  onPressed: () => onChanged([...ts, _next(ts)]),
                  tooltip: 'Ajouter une séance',
                  iconSize: 18,
                ),
            ],
          ),
          if (times == null && autoCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${plural(autoCount, 'séance')} placée${autoCount > 1 ? 's' : ''} par le planning. Ajoutez les créneaux pour choisir jour et heures.',
                style: AppText.body(13, color: AppColors.neutral700),
              ),
            ),
          for (var i = 0; i < ts.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Tap(
                      onTap: () => _pickDay(context, ts, i),
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.divider),
                      constraints: const BoxConstraints(minHeight: 44),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(dayNamesShort[ts[i].day], style: AppText.body(16)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  TimeField(
                    value: toHhMm(ts[i].start),
                    width: 76,
                    onChanged: (v) {
                      final st = parseTime(v)!;
                      final en = ts[i].end > st ? ts[i].end : min(st + 120, 1439);
                      _set(ts, i, (day: ts[i].day, start: st, end: en));
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text('–', style: AppText.body(16)),
                  ),
                  TimeField(
                    value: toHhMm(ts[i].end),
                    width: 76,
                    onChanged: (v) {
                      final en = parseTime(v)!;
                      final st = ts[i].start < en ? ts[i].start : max(en - 120, 0);
                      _set(ts, i, (day: ts[i].day, start: st, end: en));
                    },
                  ),
                  const SizedBox(width: 6),
                  SquareIconButton(
                    icon: AppIcons.x,
                    onPressed: () => onChanged([...ts]..removeAt(i)),
                    tooltip: 'Retirer la séance',
                    iconSize: 18,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CatchupRow extends StatelessWidget {
  const _CatchupRow({required this.app, required this.due, required this.on, required this.onToggle});

  final AppState app;
  final Due due;
  final bool on;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final u = due;
    final ps = app.sessionById(u.placedSession);
    return Tap(
      onTap: onToggle,
      border: Border.all(color: AppColors.divider),
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: on ? AppColors.accent : Colors.transparent,
              border: Border.all(color: on ? AppColors.accent : AppColors.neutral500, width: 1.5),
            ),
            alignment: Alignment.center,
            child: on ? const AppIcon(AppIcons.check, size: 16, color: AppColors.bg, strokeWidth: 2) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${u.cls != null ? app.classes[u.cls]!.name : app.svc(u.svc).name} · manquée ${u.from}',
                  style: AppText.body(15, weight: FontWeight.w500),
                ),
                Text(
                  '${app.whoLabel(u)}${u.motif.isNotEmpty ? ' · ${u.motif}' : ''}${ps != null ? ' · placée ${dayShort(ps.week, ps.day)}' : ''}',
                  style: AppText.body(13, color: AppColors.neutral700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
