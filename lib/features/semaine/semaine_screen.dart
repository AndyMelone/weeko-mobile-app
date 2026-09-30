import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/formats.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/blueprint.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/misc.dart';
import '../../data/demo_data.dart';
import '../../data/models/models.dart';
import '../../logic/app_state.dart';
import '../../logic/nav_state.dart';
import '../shared/screen_header.dart';
import '../shared/session_row.dart';

class _Alert {
  const _Alert(this.title, this.detail, this.action, this.onTap);

  final String title;
  final String detail;
  final String action;
  final VoidCallback onTap;
}

/// Ligne affichée dans un jour : séance ou trajet entre deux séances.
sealed class _DayRow {}

class _SessionItem extends _DayRow {
  _SessionItem(this.session);
  final Session session;
}

class _GapItem extends _DayRow {
  _GapItem(this.label, this.bad);
  final String label;
  final bool bad;
}

class _Day {
  _Day({
    required this.day,
    required this.label,
    required this.offLabel,
    required this.rows,
    required this.isEmpty,
    required this.emptyLabel,
    required this.todayNote,
  });

  final int day;
  final String label;
  final String offLabel;
  final List<_DayRow> rows;
  final bool isEmpty;
  final String emptyLabel;
  final String todayNote;
}

/// Écran 1 : Ma semaine (accueil).
class SemaineScreen extends StatefulWidget {
  const SemaineScreen({super.key});

  @override
  State<SemaineScreen> createState() => _SemaineScreenState();
}

class _SemaineScreenState extends State<SemaineScreen> {
  final _scroll = ScrollController();
  final _dayKeys = <int, GlobalKey>{};

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _consumeScrollTarget(NavState nav) {
    final t = nav.scrollTarget;
    if (t == null || t.week != nav.week) return;
    nav.scrollTarget = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (t.week == 0 && t.day == demoToday) {
        _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        return;
      }
      final ctx = _dayKeys[t.day]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final nav = context.watch<NavState>();
    final w = nav.week;
    _consumeScrollTarget(nav);

    final sessions = app.week(w);
    final kicker = w == 0
        ? 'Cette semaine'
        : w > 0
        ? 'À venir'
        : 'Passée';
    final header = WeekHeader(
      kicker: kicker,
      label: weekRange(w),
      onPrev: () => nav.setWeek(w - 1),
      onNext: () => nav.setWeek(w + 1),
    );

    if (!app.generated.contains(w) && sessions.isEmpty) {
      return Column(
        children: [
          header,
          Expanded(
            child: ScreenBody(padding: const EdgeInsets.fromLTRB(16, 26, 16, 24), children: [_noWeek(nav, w)]),
          ),
        ],
      );
    }

    final alerts = <_Alert>[];
    final days = <_Day>[];
    for (var d = 0; d < 7; d++) {
      final list = sessions.where((s) => s.day == d).toList()..sort((a, b) => a.start - b.start);
      final rows = <_DayRow>[];
      final off = app.off(d, w);
      for (var i = 0; i < list.length; i++) {
        final s = list[i];
        if (i > 0) {
          final p = list[i - 1], need = app.travel((svc: p.svc), (svc: s.svc)), margin = s.start - p.end - need;
          final bad = margin < 0 || (need >= 30 && margin < tightMargin);
          if (bad) {
            alerts.add(
              _Alert(
                app.travelEnabled ? '${dayNamesLong[d]} · trajet serré' : '${dayNamesLong[d]} · chevauchement',
                app.travelEnabled
                    ? '${app.titleOf(p)} finit à ${fmt(p.end)}, ${app.titleOf(s)} commence à ${fmt(s.start)} : $need min de trajet, ${margin <= 0 ? 'aucune marge.' : '$margin min de marge.'}'
                    : '${app.titleOf(p)} finit à ${fmt(p.end)}, ${app.titleOf(s)} commence à ${fmt(s.start)}.',
                'Voir',
                () => nav.openPointer(s.id),
              ),
            );
          }
          if (need > 0) {
            final suffix = !bad
                ? ''
                : margin < 0
                ? ' · impossible'
                : margin == 0
                ? ' · serré, aucune marge'
                : ' · serré, $margin min de marge';
            rows.add(_GapItem('Trajet $need min$suffix', bad));
          }
        }
        rows.add(_SessionItem(s));
      }
      if (off != null && list.isNotEmpty && list.first.start < off + app.fromWork) {
        alerts.add(
          _Alert(
            app.travelEnabled
                ? '${dayNamesLong[d]} · trajet impossible'
                : '${dayNamesLong[d]} · avant la sortie du travail',
            'Sortie à ${fmt(off)}, ${app.titleOf(list.first)} commence à ${fmt(list.first.start)}.',
            'Voir',
            () => nav.openPointer(list.first.id),
          ),
        );
      }
      final rest = list.where((s) => s.status == SessionStatus.prevue).length;
      days.add(
        _Day(
          day: d,
          label: '${dayNamesLong[d]} ${dateOf(w, d).day}',
          offLabel: off != null ? 'Sortie ${fmt(off)}' : 'Pas de travail',
          rows: rows,
          isEmpty: list.isEmpty,
          emptyLabel: off != null && off >= 1080 ? 'Soirée libre' : 'Journée libre',
          todayNote: list.isEmpty
              ? 'Rien de prévu'
              : (rest > 0 ? '$rest à pointer sur ${list.length}' : 'Tout est pointé'),
        ),
      );
    }
    if (!app.generated.contains(w)) {
      alerts.add(
        _Alert(
          'Semaine pas encore générée',
          'Seules les séances déjà casées apparaissent.',
          'Préparer',
          () => nav.openPreparer(w),
        ),
      );
    }
    for (final c in app.classes.values) {
      final n = app.unplaced(c.id, w);
      if (n > 0) {
        alerts.add(
          _Alert(
            '${c.name} · ${app.svc(c.siteId).name}',
            '${plural(n, 'séance')} non placée${n > 1 ? 's' : ''} cette semaine.',
            'Caser',
            () => nav.go(AppScreen.rattrapages),
          ),
        );
      }
    }
    if (w == 0) {
      for (final u in app.dues.where((u) => !u.done && u.placedSession == null)) {
        alerts.add(
          _Alert(
            '${u.cls != null ? app.classes[u.cls]!.name : app.svc(u.svc).name} · séance à rattraper',
            'Manquée ${u.from}, pas encore casée.',
            'Caser',
            () => nav.go(AppScreen.rattrapages),
          ),
        );
      }
    }

    final mins = sessions.fold(0, (a, s) => a + s.end - s.start);
    final faites = sessions.where((s) => s.status == SessionStatus.faite || s.status == SessionStatus.rattrapee).length;
    final h = mins ~/ 60, m = mins % 60;
    final summary =
        '${sessions.length} séances · $h h${m > 0 ? ' $m' : ''} de cours${faites > 0 ? ' · ${plural(faites, 'faite')}' : ''}';
    final today = w == 0 ? days.where((x) => x.day == demoToday).firstOrNull : null;

    return Column(
      children: [
        header,
        Expanded(
          child: ScreenBody(
            controller: _scroll,
            gap: 18,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(summary, style: AppText.body(14, color: AppColors.neutral700)),
                    ),
                    if (w != 0) GhostButton(label: "Aujourd'hui", onPressed: nav.goToday),
                  ],
                ),
              ),
              if (today != null) _TodayBlock(note: today.todayNote, child: _dayContent(app, nav, today, isToday: true)),
              if (alerts.isNotEmpty) _AlertsCard(alerts: alerts),
              for (final d in days)
                if (d != today)
                  KeyedSubtree(key: _dayKeys.putIfAbsent(d.day, GlobalKey.new), child: _dayContent(app, nav, d)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _noWeek(NavState nav, int w) {
    return Blueprint(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Semaine non préparée', style: AppText.heading(22)),
          const SizedBox(height: 12),
          Text(
            'Aucun planning pour cette semaine. Elle peut être préparée dès maintenant.',
            style: AppText.body(14, color: AppColors.neutral700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PrimaryButton(
                label: 'Préparer cette semaine',
                onPressed: () => nav.openPreparer(w),
                height: 44,
                fontSize: 16,
              ),
              SecondaryButton(label: "Aujourd'hui", onPressed: nav.goToday, fontSize: 16),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayContent(AppState app, NavState nav, _Day d, {bool isToday = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  d.label.toUpperCase(),
                  style: AppText.heading(
                    18,
                    color: isToday ? AppColors.accent900 : AppColors.text,
                    letterSpacing: 18 * .04,
                  ),
                ),
              ),
              Text(d.offLabel, style: AppText.body(13, color: AppColors.neutral700)),
            ],
          ),
        ),
        if (d.isEmpty) ...[
          const SizedBox(height: 6),
          DashedNote(
            color: AppColors.neutral400,
            minHeight: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(d.emptyLabel, style: AppText.body(14, color: AppColors.neutral700)),
          ),
        ],
        for (final r in d.rows) ...[
          const SizedBox(height: 6),
          switch (r) {
            _SessionItem(:final session) => SessionRow(
              session: session,
              app: app,
              onTap: () => nav.openPointer(session.id),
            ),
            _GapItem(:final label, :final bad) => _TravelGap(label: label, bad: bad),
          },
        ],
      ],
    );
  }
}

/// Bloc « Aujourd'hui » : cadre accent, bandeau plein.
class _TodayBlock extends StatelessWidget {
  const _TodayBlock({required this.child, required this.note});

  final Widget child;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.accent100,
        border: Border.all(color: AppColors.accent700, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: AppColors.accent700,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text("AUJOURD'HUI", style: AppText.heading(14, color: Colors.white, letterSpacing: 1.4)),
                ),
                Text(note, style: AppText.body(13, color: Colors.white)),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(10, 4, 10, 10), child: child),
        ],
      ),
    );
  }
}

class _TravelGap extends StatelessWidget {
  const _TravelGap({required this.label, required this.bad});

  final String label;
  final bool bad;

  @override
  Widget build(BuildContext context) {
    final c = bad ? AppColors.neutral900 : AppColors.neutral600;
    return Padding(
      padding: const EdgeInsets.only(left: 30),
      child: Row(
        children: [
          Container(width: 1, height: 16, color: c),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: AppText.body(12, color: c, weight: bad ? FontWeight.w700 : FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertsCard extends StatelessWidget {
  const _AlertsCard({required this.alerts});

  final List<_Alert> alerts;

  @override
  Widget build(BuildContext context) {
    return Blueprint(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: AppColors.neutral900,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const AppIcon(AppIcons.alertTriangle, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'À TRAITER · ${alerts.length}',
                  style: AppText.heading(16, color: Colors.white, letterSpacing: 16 * .04),
                ),
              ],
            ),
          ),
          for (final a in alerts)
            Tap(
              onTap: a.onTap,
              border: const Border(top: BorderSide(color: AppColors.divider)),
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.title, style: AppText.body(15, weight: FontWeight.w500)),
                        Text(a.detail, style: AppText.body(13, color: AppColors.neutral700)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(a.action, style: AppText.heading(14, color: AppColors.accent700)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
