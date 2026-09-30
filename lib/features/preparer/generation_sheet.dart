import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/formats.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/blueprint.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/misc.dart';
import '../../data/models/models.dart';
import '../../logic/app_state.dart';

Future<bool?> showGenerationSheet(
  BuildContext context, {
  required AppState app,
  required int week,
  required String message,
  required List<Session> sessions,
}) {
  return showModalBottomSheet<bool>(
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

  @override
  Widget build(BuildContext context) {
    final app = widget.app, w = widget.week;
    final preview = widget.sessions;
    final sessions = app.sortedWeek(w, preview);

    final body = switch (_tab) {
      _Tab.recap => [
        _CopyCard(
          text: app.recapOf(w, preview),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var d = 0; d < 7; d++)
                if (sessions.any((s) => s.day == d)) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 4),
                    child: Text(dayLong(w, d), style: AppText.heading(17)),
                  ),
                  for (final s in sessions.where((s) => s.day == d)) _SessionLine(app: app, session: s),
                ],
              if (sessions.isEmpty) Text('Aucune séance cette semaine.', style: AppText.body(15)),
            ],
          ),
        ),
      ],
      _Tab.collectif => [
        _CopyCard(
          text: app.collectiveOf(w, preview),
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
          _CopyCard(
            text: app.programmeOf(id, w, preview),
            child: Text(app.programmeOf(id, w, preview), style: AppText.body(14, height: 1.5)),
          ),
          const SizedBox(height: 14),
        ],
      ],
    };

    return SafeArea(
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
                Text(
                  '${widget.message.replaceFirst(RegExp(r'^Planning du [^:]+: '), '')} · rien n’est enregistré avant validation.',
                  style: AppText.body(14, color: AppColors.neutral700),
                ),
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
                  child: SecondaryButton(label: 'Annuler', height: 52, onPressed: () => Navigator.pop(context, false)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: PrimaryButton(label: 'Valider le planning', onPressed: () => Navigator.pop(context, true)),
                ),
              ],
            ),
          ),
        ],
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
