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
import '../../core/widgets/status_tag.dart';
import '../../data/api/api_client.dart';
import '../../data/models/models.dart';
import '../../logic/app_state.dart';
import '../../logic/nav_state.dart';
import '../shared/screen_header.dart';
import 'ics_export.dart';

class RattrapagesScreen extends StatefulWidget {
  const RattrapagesScreen({super.key});

  @override
  State<RattrapagesScreen> createState() => _RattrapagesScreenState();
}

class _RattrapagesScreenState extends State<RattrapagesScreen> {
  final _sel = <String, SlotChoice>{};

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final nav = context.read<NavState>();
    final items = app.items();
    final todo = items.where((i) => i.placed == null).length;

    return Column(
      children: [
        HeaderBar(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text((todo > 0 ? '$todo à placer' : 'Tout est placé').toUpperCase(), style: AppText.kicker),
              Text('Rattrapages', style: AppText.heading(26, height: 1.1)),
            ],
          ),
        ),
        Expanded(
          child: ScreenBody(
            gap: 22,
            children: [
              for (final it in items)
                _ItemCard(
                  key: ValueKey(it.key),
                  app: app,
                  item: it,
                  choice: _sel[it.key],
                  onChoice: (c) => setState(() => _sel[it.key] = c),
                  onPlace: () async {
                    try {
                      final msg = await app.place(it, _sel[it.key]);
                      if (msg != null) nav.showToast(msg);
                    } on ApiException catch (e) {
                      nav.showToast(e.message);
                    }
                  },
                  onView: () => nav.goDay(it.placedSession!.week, it.placedSession!.day),
                  onCancel: () async {
                    try {
                      nav.showToast(await app.cancelRattrapage(it));
                    } on ApiException catch (e) {
                      nav.showToast(e.message);
                    }
                  },
                ),
              if (items.isEmpty)
                Text(
                  'Aucune séance à rattraper. Tout est à jour.',
                  style: AppText.body(15, color: AppColors.neutral700),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    super.key,
    required this.app,
    required this.item,
    required this.choice,
    required this.onChoice,
    required this.onPlace,
    required this.onView,
    required this.onCancel,
  });

  final AppState app;
  final RattItem item;
  final SlotChoice? choice;
  final ValueChanged<SlotChoice> onChoice;
  final VoidCallback onPlace;
  final VoidCallback onView;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final it = item;
    final S = app.svc(it.svc);
    final isPlaced = it.placed != null;
    final tag = isPlaced ? TagKind.casee : (it.isDue ? TagKind.due : TagKind.nonPlacee);
    final w0 = it.week;
    final props = isPlaced ? const [] : app.proposals(it);

    String? manual;
    var manualOk = false;
    if (choice case DayChoice(:final day)) {
      final s = app.slots(it.svc, onlyDay: day, w: w0).firstOrNull;
      manualOk = s != null;
      manual = s != null ? '${dayLong(w0, day)} : ${range(s.start, s.end)} possible.' : app.reason(it, day);
    }
    final canPlace = choice is ProposalChoice || manualOk;

    return Blueprint(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CodeBadge(code: S.code, color: S.color),
              const SizedBox(width: 10),
              Expanded(child: Text(it.title, style: AppText.heading(19, height: 1.15))),
              const SizedBox(width: 10),
              StatusTag(tag),
            ],
          ),
          const SizedBox(height: 12),
          Text(it.detail, style: AppText.body(14, color: AppColors.neutral700)),
          if (isPlaced) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const AppIcon(AppIcons.check, size: 18, color: AppColors.accent800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Placée : ${it.placed}',
                    style: AppText.body(15, weight: FontWeight.w500, color: AppColors.accent800),
                  ),
                ),
              ],
            ),
            if (it.placedSession != null) ...[
              const SizedBox(height: 12),
              Text('Ajoutée à ton planning du jour.', style: AppText.body(13, color: AppColors.neutral700)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(label: 'Voir le jour', onPressed: onView),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SecondaryButton(
                      label: 'Agenda du téléphone',
                      icon: AppIcons.calendarPlus,
                      onPressed: () => shareSessionIcs(app, it.placedSession!),
                    ),
                  ),
                ],
              ),
              if (it.isDue && it.placedSession!.status == SessionStatus.prevue) ...[
                const SizedBox(height: 8),
                SecondaryButton(label: 'Annuler le rattrapage', icon: AppIcons.x, onPressed: onCancel),
              ],
            ],
          ] else ...[
            if (props.isNotEmpty && props.every((p) => p.week > w0)) ...[
              const SizedBox(height: 12),
              DashedNote(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Text(
                  'Aucun créneau libre cette semaine avec les règles ${app.travelEnabled ? 'de trajet et d’horaires' : 'd’horaires'}. Propositions pour la semaine suivante${app.generated.contains(w0 + 1) ? '.' : ', à confirmer.'}',
                  style: AppText.body(13),
                ),
              ),
            ],
            const SizedBox(height: 12),
            const SectionTitle('Créneaux proposés', fontSize: 13),
            for (var i = 0; i < props.length; i++) ...[
              const SizedBox(height: 6),
              _ProposalTile(
                label: '${dayShort(props[i].week, props[i].day)} · ${range(props[i].start, props[i].end)}',
                sub: props[i].week == currentWeek ? 'Cette semaine' : 'Semaine du ${weekRange(props[i].week)}',
                selected: switch (choice) {
                  ProposalChoice(:final index) => index == i,
                  _ => false,
                },
                onTap: () => onChoice(ProposalChoice(i)),
              ),
            ],
            const SizedBox(height: 12),
            const SectionTitle('Ou choisir un jour', fontSize: 13),
            const SizedBox(height: 12),
            Segmented(
              height: 52,
              fontSize: 11,
              options: [
                for (var d = 0; d < 7; d++)
                  SegOption(
                    label: dayNamesShort[d],
                    sub: '${dateOf(w0, d).day}',
                    selected: switch (choice) {
                      DayChoice(:final day) => day == d,
                      _ => false,
                    },
                    onTap: () => onChoice(DayChoice(d)),
                  ),
              ],
            ),
            if (manual != null) ...[
              const SizedBox(height: 12),
              Text(manual, style: AppText.body(14, color: manualOk ? AppColors.accent800 : AppColors.neutral800)),
            ],
            const SizedBox(height: 12),
            PrimaryButton(label: 'Ajouter au planning', height: 48, fontSize: 17, onPressed: canPlace ? onPlace : null),
          ],
        ],
      ),
    );
  }
}

class _ProposalTile extends StatelessWidget {
  const _ProposalTile({required this.label, required this.sub, required this.selected, required this.onTap});

  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bd = selected ? AppColors.accent : AppColors.divider;
    return Tap(
      onTap: onTap,
      color: selected ? AppColors.accent100 : Colors.transparent,
      border: Border.all(color: bd),
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: bd, width: 1.5),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.accent : Colors.transparent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.heading(17)),
                Text(sub, style: AppText.body(12, color: AppColors.neutral700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
