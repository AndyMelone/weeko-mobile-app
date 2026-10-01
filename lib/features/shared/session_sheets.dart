import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/formats.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/confirm_sheet.dart';
import '../../core/widgets/misc.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/status_tag.dart';
import '../../data/api/api_client.dart';
import '../../data/models/models.dart';
import '../../logic/app_state.dart';
import '../../logic/labels.dart';
import '../../logic/nav_state.dart';
import '../rattrapages/ics_export.dart';

// Feuilles du bas liées aux séances (l'app n'utilise pas de popup).

Future<T?> _sheet<T>(BuildContext context, Widget Function(BuildContext ctx) builder) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  backgroundColor: AppColors.bg,
  shape: const RoundedRectangleBorder(),
  builder: (ctx) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 16), child: builder(ctx)),
    ),
  ),
);

// ─── Feuille d'une séance ─────────────────────────────────────

/// Toucher une séance : pointer, déplacer, annuler, agenda, prévenir le parent.
Future<void> showSessionSheet(BuildContext context, AppState app, NavState nav, Session s) async {
  final S = app.svc(s.svc);
  final planned = s.status == SessionStatus.prevue;
  final started = app.hasStarted(s);
  final action = await _sheet<String>(
    context,
    (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${s.isRattrapage ? 'Rattrapage · ' : ''}${app.titleOf(s)}${s.cls != null ? ' · ${S.name}' : ''}',
                style: AppText.heading(22),
              ),
            ),
            StatusTag(tagOfSession(s)),
          ],
        ),
        const SizedBox(height: 4),
        Text('${dayLong(s.week, s.day)} · ${range(s.start, s.end)}', style: AppText.body(15)),
        const SizedBox(height: 16),
        if (started || !planned) ...[
          PrimaryButton(label: 'Pointer la séance', onPressed: () => Navigator.pop(ctx, 'pointer')),
          const SizedBox(height: 8),
        ] else ...[
          Text(
            'Séance à venir : tu pourras la pointer à partir de ${fmt(s.start)} le ${dayLong(s.week, s.day).toLowerCase()}.',
            style: AppText.body(13, color: AppColors.neutral700),
          ),
          const SizedBox(height: 12),
        ],
        if (planned) ...[
          SecondaryButton(label: 'Changer l’heure ou le jour', onPressed: () => Navigator.pop(ctx, 'move')),
          const SizedBox(height: 8),
          SecondaryButton(label: 'Échanger avec…', onPressed: () => Navigator.pop(ctx, 'swap')),
          const SizedBox(height: 8),
          SecondaryButton(
            label: s.isRattrapage ? 'Annuler le rattrapage' : 'Annuler · prévenir une absence',
            icon: AppIcons.x,
            onPressed: () => Navigator.pop(ctx, 'cancel'),
          ),
          const SizedBox(height: 8),
          SecondaryButton(label: 'Supprimer la séance', onPressed: () => Navigator.pop(ctx, 'delete')),
          const SizedBox(height: 8),
        ],
        SecondaryButton(
          label: 'Agenda du téléphone',
          icon: AppIcons.calendarPlus,
          onPressed: () => Navigator.pop(ctx, 'ics'),
        ),
        if (S.isEleve && S.phone.isNotEmpty && planned) ...[
          const SizedBox(height: 8),
          SecondaryButton(
            label: 'Rappel au parent (WhatsApp)',
            icon: AppIcons.send,
            onPressed: () => Navigator.pop(ctx, 'whatsapp'),
          ),
        ],
        const SizedBox(height: 8),
        GhostButton(label: 'Fermer', onPressed: () => Navigator.pop(ctx)),
      ],
    ),
  );
  if (!context.mounted || action == null) return;
  try {
    switch (action) {
      case 'pointer':
        nav.openPointer(s.id);
      case 'move':
        final to = await showSlotSheet(
          context,
          title: 'Changer l’heure ou le jour',
          initial: Slot(week: s.week, day: s.day, start: s.start, end: s.end),
        );
        if (to != null) nav.showToast(withGaps(app, await app.moveSession(s.id, to), {s.week, to.week}, [s.svc]));
      case 'swap':
        final other = await showSwapPicker(context, app, s);
        if (other != null) await swapAndNotify(app, nav, s, other);
      case 'delete':
        final ok = await showConfirmSheet(
          context,
          title: 'Supprimer cette séance ?',
          message:
              '${app.titleOf(s)} · ${dayLong(s.week, s.day)} sort du planning, sans séance à rattraper. '
              'Pour une absence à rattraper, utilisez « Annuler · prévenir une absence ».',
          confirmLabel: 'Supprimer',
        );
        if (ok) nav.showToast(withGaps(app, await app.cancelSession(s.id, redo: false), {s.week}, [s.svc]));
      case 'cancel':
        if (s.isRattrapage) {
          nav.showToast(await app.cancelSession(s.id, redo: false));
          return;
        }
        final d = await showCancelSheet(context, title: 'Annuler · ${app.titleOf(s)}', who: S.isEleve);
        if (d != null) {
          nav.showToast(
            withGaps(app, await app.cancelSession(s.id, redo: d.redo, who: d.who, motif: d.motif), {s.week}, [s.svc]),
          );
        }
      case 'ics':
        await shareSessionIcs(app, s);
      case 'whatsapp':
        final msg =
            'Bonjour, petit rappel : séance de ${S.first} le ${dayLong(s.week, s.day).toLowerCase()} de ${range(s.start, s.end)}. À bientôt.';
        final ok = await launchUrl(
          Uri.parse('https://wa.me/${S.phone}?text=${Uri.encodeComponent(msg)}'),
          mode: LaunchMode.externalApplication,
        );
        if (!ok) nav.showToast('Impossible d’ouvrir WhatsApp');
    }
  } on ApiException catch (e) {
    nav.showToast(e.message);
  }
}

/// Texte du toast, complété si le nombre de séances d'un élève change
/// dans les semaines [weeks] (ex. « Sondo : 1 séance au lieu de 2 »).
String withGaps(AppState app, String msg, Set<int> weeks, Iterable<String> svcs) {
  final gaps = [
    for (final w in weeks)
      for (final g in app.countGaps(w))
        if (svcs.contains(g.svc)) '${app.gapLabel(g)}${weeks.length > 1 ? ' (semaine ${weekNum(w)})' : ''}',
  ];
  return gaps.isEmpty ? msg : '$msg · Attention : ${gaps.join(' · ')}';
}

/// Échange deux séances puis affiche le toast (ou l'erreur, ex. deux séances le même jour).
Future<void> swapAndNotify(AppState app, NavState nav, Session a, Session b) async {
  try {
    final msg = await app.swapSessions(a.id, b.id);
    nav.showToast(withGaps(app, msg, {a.week, b.week}, [a.svc, b.svc]));
  } on ApiException catch (e) {
    nav.showToast(e.message);
  }
}

/// Choix de la séance avec laquelle échanger [s] (séances prévues de la même semaine).
Future<Session?> showSwapPicker(BuildContext context, AppState app, Session s) {
  final others = app.week(s.week).where((o) => o.id != s.id && o.status == SessionStatus.prevue).toList()
    ..sort((a, b) => a.day != b.day ? a.day - b.day : a.start - b.start);
  return _sheet<Session>(
    context,
    (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Échanger ${app.titleOf(s)} avec…', style: AppText.heading(22)),
        const SizedBox(height: 4),
        Text(
          'Les deux séances échangent leur jour et leurs heures.',
          style: AppText.body(14, color: AppColors.neutral700),
        ),
        const SizedBox(height: 12),
        for (final o in others)
          Tap(
            onTap: () => Navigator.pop(ctx, o),
            border: const Border(bottom: BorderSide(color: AppColors.divider)),
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Text('${dayNamesShort[o.day]} ${range(o.start, o.end)}', style: AppText.heading(15)),
                ),
                CodeBadge(code: app.svc(o.svc).code, color: app.svc(o.svc).color, size: 22, fontSize: 10),
                const SizedBox(width: 8),
                Expanded(child: Text(app.titleOf(o), style: AppText.body(15))),
              ],
            ),
          ),
        if (others.isEmpty) Text('Aucune autre séance prévue cette semaine.', style: AppText.body(15)),
        const SizedBox(height: 12),
        GhostButton(label: 'Fermer', onPressed: () => Navigator.pop(ctx)),
      ],
    ),
  );
}

// ─── Choix d'un créneau (semaine, jour, heures) ───────────────

/// Créneau saisi à la main. Retourne null si annulé.
Future<Slot?> showSlotSheet(BuildContext context, {required String title, required Slot initial, String? note}) =>
    _sheet<Slot>(context, (ctx) => _SlotSheet(title: title, initial: initial, note: note));

class _SlotSheet extends StatefulWidget {
  const _SlotSheet({required this.title, required this.initial, this.note});

  final String title;
  final Slot initial;
  final String? note;

  @override
  State<_SlotSheet> createState() => _SlotSheetState();
}

class _SlotSheetState extends State<_SlotSheet> {
  late int _week = widget.initial.week, _day = widget.initial.day;
  late String _start = toHhMm(widget.initial.start), _end = toHhMm(widget.initial.end);

  @override
  Widget build(BuildContext context) {
    final st = parseTime(_start)!, en = parseTime(_end)!;
    final ok = en > st;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.title, style: AppText.heading(22)),
        if (widget.note != null) ...[
          const SizedBox(height: 4),
          Text(widget.note!, style: AppText.body(13, color: AppColors.neutral700)),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            SquareIconButton(
              icon: AppIcons.chevronLeft,
              tooltip: 'Semaine précédente',
              onPressed: () {
                if (_week > currentWeek) setState(() => _week--);
              },
            ),
            Expanded(
              child: Text(
                '${_week == currentWeek ? 'Cette semaine' : 'Semaine'} · ${weekRange(_week)}',
                textAlign: TextAlign.center,
                style: AppText.body(15, weight: FontWeight.w500),
              ),
            ),
            SquareIconButton(
              icon: AppIcons.chevronRight,
              tooltip: 'Semaine suivante',
              onPressed: () => setState(() => _week++),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Segmented(
          height: 52,
          fontSize: 12,
          options: [
            for (var d = 0; d < 7; d++)
              SegOption(
                label: dayNamesShort[d],
                sub: '${dateOf(_week, d).day}',
                selected: _day == d,
                onTap: () => setState(() => _day = d),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FieldLabel(
                label: 'Début',
                child: TimeField(value: _start, onChanged: (v) => setState(() => _start = v)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FieldLabel(
                label: 'Fin',
                child: TimeField(value: _end, onChanged: (v) => setState(() => _end = v)),
              ),
            ),
          ],
        ),
        if (!ok) ...[
          const SizedBox(height: 6),
          Text('La fin doit être après le début.', style: AppText.body(13, color: AppColors.neutral700)),
        ],
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'Valider ${dayShort(_week, _day)} · ${ok ? range(st, en) : '…'}',
          onPressed: ok ? () => Navigator.pop(context, Slot(week: _week, day: _day, start: st, end: en)) : null,
        ),
        const SizedBox(height: 8),
        SecondaryButton(label: 'Annuler', onPressed: () => Navigator.pop(context)),
      ],
    );
  }
}

// ─── Annulation d'une séance prévue ───────────────────────────

/// Absence prévenue : qui, motif (facultatif), à rattraper. Null si annulé.
Future<({bool redo, Who? who, String motif})?> showCancelSheet(
  BuildContext context, {
  required String title,
  required bool who,
}) => _sheet(context, (ctx) => _CancelSheet(title: title, askWho: who));

class _CancelSheet extends StatefulWidget {
  const _CancelSheet({required this.title, required this.askWho});

  final String title;
  final bool askWho;

  @override
  State<_CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends State<_CancelSheet> {
  Who _who = Who.eleve;
  bool _redo = true;
  final _motif = TextEditingController();

  @override
  void dispose() {
    _motif.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.title, style: AppText.heading(22)),
        const SizedBox(height: 16),
        FieldLabel(
          label: 'Qui sera absent ?',
          child: Segmented(
            options: [
              SegOption(label: 'Moi', selected: _who == Who.moi, onTap: () => setState(() => _who = Who.moi)),
              SegOption(
                label: widget.askWho ? 'L’élève' : 'La classe',
                selected: _who == Who.eleve,
                onTap: () => setState(() => _who = Who.eleve),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FieldLabel(
          label: 'Rattrapage',
          child: Segmented(
            options: [
              SegOption(label: 'À rattraper', selected: _redo, onTap: () => setState(() => _redo = true)),
              SegOption(label: 'Pas de rattrapage', selected: !_redo, onTap: () => setState(() => _redo = false)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FieldLabel(
          label: 'Motif (facultatif)',
          child: AppTextField(controller: _motif, hint: 'Ex. Voyage'),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'Annuler la séance',
          onPressed: () => Navigator.pop(context, (redo: _redo, who: _who, motif: _motif.text.trim())),
        ),
        const SizedBox(height: 8),
        SecondaryButton(label: 'Retour', onPressed: () => Navigator.pop(context)),
      ],
    );
  }
}

// ─── Indisponibilités ─────────────────────────────────────────

/// Liste modifiable de plages indisponibles (jour + de / à).
class BlocksEditor extends StatelessWidget {
  const BlocksEditor({super.key, required this.blocks, required this.onChanged});

  final List<TimeBlock> blocks;
  final ValueChanged<List<TimeBlock>> onChanged;

  void _set(int i, TimeBlock b) => onChanged([for (var k = 0; k < blocks.length; k++) k == i ? b : blocks[k]]);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(border: Border.all(color: AppColors.divider)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Segmented(
                  height: 40,
                  fontSize: 12,
                  options: [
                    for (var d = 0; d < 7; d++)
                      SegOption(
                        label: dayNamesShort[d],
                        selected: blocks[i].day == d,
                        onTap: () => _set(i, TimeBlock(day: d, start: blocks[i].start, end: blocks[i].end)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('de', style: AppText.body(13, color: AppColors.neutral700)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TimeField(
                        value: toHhMm(blocks[i].start),
                        onChanged: (v) =>
                            _set(i, TimeBlock(day: blocks[i].day, start: parseTime(v)!, end: blocks[i].end)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('à', style: AppText.body(13, color: AppColors.neutral700)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TimeField(
                        value: blocks[i].end >= 1440 ? '23:59' : toHhMm(blocks[i].end),
                        onChanged: (v) {
                          final m = parseTime(v)!;
                          _set(i, TimeBlock(day: blocks[i].day, start: blocks[i].start, end: m >= 1439 ? 1440 : m));
                        },
                      ),
                    ),
                    SquareIconButton(
                      icon: AppIcons.x,
                      tooltip: 'Retirer',
                      onPressed: () => onChanged([...blocks]..removeAt(i)),
                    ),
                  ],
                ),
                if (blocks[i].end <= blocks[i].start)
                  Text('La fin doit être après le début.', style: AppText.body(12, color: AppColors.neutral700)),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        SecondaryButton(
          label: 'Ajouter une indisponibilité',
          icon: AppIcons.plus,
          onPressed: () => onChanged([...blocks, const TimeBlock(day: 5, start: 720, end: 1440)]),
        ),
        const SizedBox(height: 4),
        Text('« 23:59 » = jusqu’à la fin de la journée.', style: AppText.body(12, color: AppColors.neutral700)),
      ],
    );
  }
}

/// Indisponibilités du répétiteur, modifiées dans une feuille. Null si annulé.
Future<List<TimeBlock>?> showBlocksSheet(
  BuildContext context, {
  required String title,
  required List<TimeBlock> initial,
}) => _sheet(context, (ctx) => _BlocksSheet(title: title, initial: initial));

class _BlocksSheet extends StatefulWidget {
  const _BlocksSheet({required this.title, required this.initial});

  final String title;
  final List<TimeBlock> initial;

  @override
  State<_BlocksSheet> createState() => _BlocksSheetState();
}

class _BlocksSheetState extends State<_BlocksSheet> {
  late List<TimeBlock> _blocks = [...widget.initial];

  @override
  Widget build(BuildContext context) {
    final ok = _blocks.every((b) => b.end > b.start);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.title, style: AppText.heading(22)),
        const SizedBox(height: 16),
        BlocksEditor(blocks: _blocks, onChanged: (b) => setState(() => _blocks = b)),
        const SizedBox(height: 16),
        PrimaryButton(label: 'Enregistrer', onPressed: ok ? () => Navigator.pop(context, _blocks) : null),
        const SizedBox(height: 8),
        SecondaryButton(label: 'Annuler', onPressed: () => Navigator.pop(context)),
      ],
    );
  }
}
