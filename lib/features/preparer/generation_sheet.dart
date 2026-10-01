import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/formats.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/blueprint.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/confirm_sheet.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/misc.dart';
import '../../data/models/models.dart';
import '../../logic/app_state.dart';

/// Aperçu de la génération, modifiable avant validation : toucher une séance
/// pour la modifier, l'échanger ou la supprimer ; appui long pour la glisser
/// sur une autre séance (échange) ou sur un jour (déplacement).
/// Retourne les séances à enregistrer, null si annulé.
Future<List<Session>?> showGenerationSheet(
  BuildContext context, {
  required AppState app,
  required int week,
  required String message,
  required List<Session> sessions,
}) {
  return showModalBottomSheet<List<Session>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .9,
      maxChildSize: .9,
      minChildSize: .5,
      builder: (context, scroll) =>
          _GenerationSheet(app: app, week: week, message: message, sessions: sessions, scroll: scroll),
    ),
  );
}

enum _Tab { recap, collectif, individuel }

class _GenerationSheet extends StatefulWidget {
  const _GenerationSheet({
    required this.app,
    required this.week,
    required this.message,
    required this.sessions,
    required this.scroll,
  });

  final AppState app;
  final int week;
  final String message;

  final List<Session> sessions;
  final ScrollController scroll;

  @override
  State<_GenerationSheet> createState() => _GenerationSheetState();
}

class _GenerationSheetState extends State<_GenerationSheet> {
  _Tab _tab = _Tab.recap;

  /// Aperçu en cours de modification (rien n'est envoyé avant validation).
  late List<Session> _ss = [...widget.sessions];

  /// Séances déplacées ou échangées (tag « Modifiée »).
  final _edited = <String>{};
  bool _changed = false;

  /// Dernière modification, pour « Défaire ».
  ({List<Session> ss, Set<String> edited, bool changed})? _before;

  /// Modification refusée (règle bloquante), affichée quelques secondes.
  String? _refusal;
  Timer? _refusalTimer;

  @override
  void dispose() {
    _refusalTimer?.cancel();
    super.dispose();
  }

  /// Glisser en cours : les jours vides deviennent des zones de dépôt.
  bool _dragging = false;

  AppState get app => widget.app;
  int get w => widget.week;

  Session _byId(String id) => _ss.firstWhere((s) => s.id == id);

  void _apply(String label, List<Session> next, Iterable<String> ids) {
    final refusal = app.sameDayConflict(next);
    if (refusal != null) {
      HapticFeedback.heavyImpact();
      _refusalTimer?.cancel();
      _refusalTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _refusal = null);
      });
      setState(() => _refusal = refusal);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _refusal = null;
      _before = (ss: _ss, edited: {..._edited}, changed: _changed);
      _ss = next;
      _edited.addAll(ids);
      _changed = true;
    });
  }

  void _undo() {
    final b = _before;
    if (b == null) return;
    setState(() {
      _ss = b.ss;
      _edited
        ..clear()
        ..addAll(b.edited);
      _changed = b.changed;
      _before = null;
    });
  }

  void _move(String id, ClassTime t) {
    final s = _byId(id);
    if (s.day == t.day && s.start == t.start && s.end == t.end) return;
    _apply(
      'Séance déplacée : ${dayNamesShort[t.day]} ${range(t.start, t.end)}',
      [for (final x in _ss) x.id == id ? x.copyWith(day: t.day, start: t.start, end: t.end) : x],
      [id],
    );
  }

  void _moveToDay(String id, int day) {
    final s = _byId(id);
    _move(id, (day: day, start: s.start, end: s.end));
  }

  void _swap(String a, String b) {
    final x = _byId(a), y = _byId(b);
    _apply(
      'Séances échangées : ${app.titleOf(x)} ↔ ${app.titleOf(y)}',
      [
        for (final s in _ss)
          s.id == a
              ? s.copyWith(day: y.day, start: y.start, end: y.end)
              : s.id == b
              ? s.copyWith(day: x.day, start: x.start, end: x.end)
              : s,
      ],
      [a, b],
    );
  }

  void _delete(String id) =>
      _apply('Séance supprimée : ${app.titleOf(_byId(id))}', [..._ss.where((s) => s.id != id)], const []);

  Future<void> _actions(Session s) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(),
      builder: (ctx) => _SheetFrame(
        title: app.titleOf(s),
        subtitle: '${dayLong(w, s.day)} · ${range(s.start, s.end)}',
        children: [
          PrimaryButton(label: 'Modifier jour et heures', onPressed: () => Navigator.pop(ctx, 'edit')),
          if (_ss.length > 1) ...[
            const SizedBox(height: 8),
            SecondaryButton(label: 'Échanger avec…', onPressed: () => Navigator.pop(ctx, 'swap')),
          ],
          const SizedBox(height: 8),
          SecondaryButton(label: 'Supprimer', icon: AppIcons.x, onPressed: () => Navigator.pop(ctx, 'delete')),
          const SizedBox(height: 8),
          GhostButton(label: 'Fermer', onPressed: () => Navigator.pop(ctx)),
        ],
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'edit':
        final t = await showModalBottomSheet<ClassTime>(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppColors.bg,
          shape: const RoundedRectangleBorder(),
          builder: (_) => _SlotEditor(title: app.titleOf(s), initial: (day: s.day, start: s.start, end: s.end)),
        );
        if (t != null) _move(s.id, t);
      case 'swap':
        final other = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppColors.bg,
          shape: const RoundedRectangleBorder(),
          builder: (ctx) => _SheetFrame(
            title: 'Échanger ${app.titleOf(s)} avec…',
            subtitle: 'Les deux séances échangent leur jour et leurs heures.',
            scrollable: true,
            children: [
              for (final o in app.sortedWeek(w, _ss))
                if (o.id != s.id)
                  Tap(
                    onTap: () => Navigator.pop(ctx, o.id),
                    border: const Border(bottom: BorderSide(color: AppColors.divider)),
                    constraints: const BoxConstraints(minHeight: 48),
                    child: _SessionLine(app: app, session: o, showDay: true),
                  ),
            ],
          ),
        );
        if (other != null) _swap(s.id, other);
      case 'delete':
        _delete(s.id);
    }
  }

  Future<void> _cancel() async {
    if (_changed) {
      final ok = await showConfirmSheet(
        context,
        title: 'Abandonner les modifications ?',
        message: 'Les changements faits dans l’aperçu seront perdus. Rien n’a été enregistré.',
        confirmLabel: 'Abandonner',
        cancelLabel: 'Continuer à modifier',
      );
      if (!ok || !mounted) return;
    }
    Navigator.pop(context);
  }

  Widget _line(Session s, {bool showDay = false}) {
    final issues = app.issuesOf(s, _ss, w);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _SessionLine(app: app, session: s, showDay: showDay),
            ),
            if (_edited.contains(s.id)) const _MiniTag('Modifiée'),
          ],
        ),
        for (final i in issues)
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: AppIcon(AppIcons.alertTriangle, size: 14, color: AppColors.warning),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(i, style: AppText.body(13, color: AppColors.warning)),
                ),
              ],
            ),
          ),
      ],
    );
    return LongPressDraggable<String>(
      data: s.id,
      hapticFeedbackOnStart: true,
      onDragStarted: () => setState(() => _dragging = true),
      onDragEnd: (_) {
        if (mounted) setState(() => _dragging = false);
      },
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.sizeOf(context).width - 64,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.bg,
            border: Border.all(color: AppColors.accent),
            boxShadow: AppColors.shadowLg,
          ),
          child: _SessionLine(app: app, session: s, showDay: showDay),
        ),
      ),
      childWhenDragging: Opacity(opacity: .35, child: content),
      child: DragTarget<String>(
        onWillAcceptWithDetails: (d) => d.data != s.id,
        onAcceptWithDetails: (d) => _swap(d.data, s.id),
        builder: (context, cand, _) => Tap(
          onTap: () => _actions(s),
          color: cand.isNotEmpty ? AppColors.accent100 : Colors.transparent,
          border: Border.all(color: cand.isNotEmpty ? AppColors.accent : Colors.transparent),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: content,
        ),
      ),
    );
  }

  Widget _dayTarget(int d, {required bool empty}) => DragTarget<String>(
    onWillAcceptWithDetails: (det) => _byId(det.data).day != d,
    onAcceptWithDetails: (det) => _moveToDay(det.data, d),
    builder: (context, cand, _) => Container(
      margin: const EdgeInsets.only(top: 6, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: cand.isNotEmpty ? AppColors.accent100 : Colors.transparent,
        border: Border.all(
          color: cand.isNotEmpty
              ? AppColors.accent
              : _dragging
              ? AppColors.divider
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Text(dayLong(w, d), style: AppText.heading(17, color: empty ? AppColors.neutral600 : AppColors.text)),
          if (_dragging) ...[
            const SizedBox(width: 8),
            Text('déposer ici', style: AppText.body(12, color: AppColors.neutral600)),
          ],
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final sessions = app.sortedWeek(w, _ss);
    final warnings = sessions.fold(0, (n, s) => n + app.issuesOf(s, _ss, w).length);

    final body = switch (_tab) {
      _Tab.recap => [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Touchez une séance pour la modifier. Appui long pour la glisser sur une autre séance (échange) ou sur un jour.',
            style: AppText.body(13, color: AppColors.neutral700),
          ),
        ),
        _CopyCard(
          text: app.recapOf(w, _ss),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var d = 0; d < 7; d++)
                if (_dragging || sessions.any((s) => s.day == d)) ...[
                  _dayTarget(d, empty: !sessions.any((s) => s.day == d)),
                  for (final s in sessions.where((s) => s.day == d)) _line(s),
                ],
              if (sessions.isEmpty && !_dragging) Text('Aucune séance cette semaine.', style: AppText.body(15)),
            ],
          ),
        ),
      ],
      _Tab.collectif => [
        _CopyCard(
          text: app.collectiveOf(w, _ss),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final site in app.services.values.where((s) => !s.isEleve))
                if (sessions.any((s) => s.svc == site.id)) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 4),
                    child: Text(site.name, style: AppText.heading(17)),
                  ),
                  for (final s in sessions.where((s) => s.svc == site.id))
                    _SessionLine(app: app, session: s, showDay: true),
                ],
              if (!sessions.any((s) => s.cls != null))
                Text('Aucune séance Succès Group cette semaine.', style: AppText.body(15)),
            ],
          ),
        ),
      ],
      _Tab.individuel => [
        for (final id in app.students) ...[
          Row(
            children: [
              CodeBadge(code: app.svc(id).code, color: app.svc(id).color, size: 24, fontSize: 11),
              const SizedBox(width: 8),
              Text(app.svc(id).name, style: AppText.heading(17)),
            ],
          ),
          const SizedBox(height: 6),
          Blueprint(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final s in sessions.where((s) => s.svc == id)) _line(s, showDay: true),
                if (!sessions.any((s) => s.svc == id))
                  Text('Pas de séance cette semaine.', style: AppText.body(14, color: AppColors.neutral700)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          _CopyCard(
            text: app.programmeOf(id, w, _ss),
            child: Text(app.programmeOf(id, w, _ss), style: AppText.body(14, height: 1.5)),
          ),
          const SizedBox(height: 14),
        ],
      ],
    };

    final summary = _changed
        ? '${plural(_ss.length, 'séance')} · aperçu modifié'
        : widget.message.replaceFirst(RegExp(r'^Planning du [^:]+: '), '');

    return PopScope(
      canPop: !_changed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, color: AppColors.neutral300),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Aperçu ${weekSpan(w)}', style: AppText.heading(24)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$summary · rien n’est enregistré avant validation.',
                          style: AppText.body(14, color: AppColors.neutral700),
                        ),
                      ),
                      if (_before != null) GhostButton(label: 'Défaire', onPressed: _undo),
                    ],
                  ),
                  if (_refusal != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.warningBg,
                        border: Border.all(color: AppColors.warning),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        children: [
                          const AppIcon(AppIcons.x, size: 16, color: AppColors.warning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _refusal!,
                              style: AppText.body(13, color: AppColors.warning, weight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (warnings > 0) ...[
                    const SizedBox(height: 6),
                    Container(
                      color: AppColors.warningBg,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        children: [
                          const AppIcon(AppIcons.alertTriangle, size: 16, color: AppColors.warning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${plural(warnings, 'avertissement')} · vous pouvez valider quand même.',
                              style: AppText.body(13, color: AppColors.warning),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Segmented(
                    options: [
                      for (final (t, label) in const [
                        (_Tab.recap, 'Récap'),
                        (_Tab.collectif, 'Collectif'),
                        (_Tab.individuel, 'Individuel'),
                      ])
                        SegOption(label: label, selected: _tab == t, onTap: () => setState(() => _tab = t)),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: widget.scroll,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: body,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: SecondaryButton(label: 'Annuler', height: 52, onPressed: _cancel),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: PrimaryButton(label: 'Valider le planning', onPressed: () => Navigator.pop(context, _ss)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Contenu standard d'un bottom sheet : titre, sous-titre, actions.
class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, this.subtitle, required this.children, this.scrollable = false});

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final head = [
      Text(title, style: AppText.heading(22)),
      if (subtitle != null) ...[
        const SizedBox(height: 4),
        Text(subtitle!, style: AppText.body(14, color: AppColors.neutral700)),
      ],
      const SizedBox(height: 16),
    ];
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: scrollable
            ? ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .75),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...head,
                    Flexible(child: ListView(shrinkWrap: true, children: children)),
                  ],
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [...head, ...children],
              ),
      ),
    );
  }
}

/// Choix du jour et des heures d'une séance de l'aperçu.
class _SlotEditor extends StatefulWidget {
  const _SlotEditor({required this.title, required this.initial});

  final String title;
  final ClassTime initial;

  @override
  State<_SlotEditor> createState() => _SlotEditorState();
}

class _SlotEditorState extends State<_SlotEditor> {
  late ClassTime _t = widget.initial;

  @override
  Widget build(BuildContext context) {
    final ok = _t.end > _t.start;
    return _SheetFrame(
      title: widget.title,
      subtitle: 'Jour et heures de la séance',
      children: [
        Segmented(
          fontSize: 13,
          options: [
            for (var d = 0; d < 7; d++)
              SegOption(
                label: dayNamesShort[d],
                selected: _t.day == d,
                onTap: () => setState(() => _t = (day: d, start: _t.start, end: _t.end)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FieldLabel(
                label: 'Début',
                child: TimeField(
                  value: toHhMm(_t.start),
                  onChanged: (v) {
                    final st = parseTime(v)!;
                    // La durée est gardée quand on change le début.
                    final en = min(st + (_t.end - _t.start), 1439);
                    setState(() => _t = (day: _t.day, start: st, end: en));
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FieldLabel(
                label: 'Fin',
                child: TimeField(
                  value: toHhMm(_t.end),
                  onChanged: (v) => setState(() => _t = (day: _t.day, start: _t.start, end: parseTime(v)!)),
                ),
              ),
            ),
          ],
        ),
        if (!ok) ...[
          const SizedBox(height: 6),
          Text('La fin doit être après le début.', style: AppText.body(13, color: AppColors.warning)),
        ],
        const SizedBox(height: 16),
        PrimaryButton(label: 'Enregistrer', onPressed: ok ? () => Navigator.pop(context, _t) : null),
        const SizedBox(height: 8),
        GhostButton(label: 'Annuler', onPressed: () => Navigator.pop(context)),
      ],
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.accent100,
        border: Border.all(color: AppColors.accent300),
      ),
      child: Text(
        label,
        style: AppText.body(11, color: AppColors.accent800, weight: FontWeight.w500),
      ),
    );
  }
}

class _SessionLine extends StatelessWidget {
  const _SessionLine({required this.app, required this.session, this.showDay = false});

  final AppState app;
  final Session session;
  final bool showDay;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final S = app.svc(s.svc);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: showDay ? 130 : 96,
            child: Text(
              showDay ? '${dayNamesShort[s.day]} ${range(s.start, s.end)}' : range(s.start, s.end),
              style: AppText.heading(15),
            ),
          ),
          CodeBadge(code: S.code, color: S.color, size: 22, fontSize: 10),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${app.titleOf(s)}${s.cls != null && !showDay ? ' · ${S.name}' : ''}${s.isRattrapage ? ' · rattrapage' : ''}',
              style: AppText.body(14),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyCard extends StatefulWidget {
  const _CopyCard({required this.text, required this.child});

  final String text;
  final Widget child;

  @override
  State<_CopyCard> createState() => _CopyCardState();
}

class _CopyCardState extends State<_CopyCard> {
  bool _copied = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    setState(() => _copied = true);
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Blueprint(padding: const EdgeInsets.fromLTRB(14, 12, 48, 12), child: widget.child),
        Positioned(
          top: 2,
          right: 2,
          child: IconButton(
            tooltip: _copied ? 'Copié' : 'Copier',
            icon: AppIcon(_copied ? AppIcons.check : AppIcons.copy, color: AppColors.accent800),
            onPressed: _copy,
          ),
        ),
      ],
    );
  }
}
