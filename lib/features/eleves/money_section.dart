import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/formats.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/confirm_sheet.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/misc.dart';
import '../../data/api/api_client.dart';
import '../../logic/app_state.dart';
import '../../logic/nav_state.dart';

/// Suivi de l'argent d'un élève : tarif, bilan du mois, paiements reçus.
class MoneySection extends StatefulWidget {
  const MoneySection({super.key, required this.app, required this.nav, required this.id});

  final AppState app;
  final NavState nav;
  final String id;

  @override
  State<MoneySection> createState() => _MoneySectionState();
}

class _MoneySectionState extends State<MoneySection> {
  late int _year = clock().year, _month = clock().month;

  void _shift(int d) => setState(() {
    _month += d;
    if (_month > 12) {
      _month = 1;
      _year++;
    } else if (_month < 1) {
      _month = 12;
      _year--;
    }
  });

  Future<void> _run(Future<void> Function() fn) async {
    try {
      await fn();
    } on ApiException catch (e) {
      widget.nav.showToast(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app, id = widget.id;
    final S = app.svc(id);
    final f = app.financeOf(id, _year, _month);
    final list = app.paymentsIn(id, _year, _month);

    Widget line(String label, String value, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppText.body(15))),
          Text(value, style: strong ? AppText.heading(18) : AppText.body(15, weight: FontWeight.w500)),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: SectionTitle('Paiements')),
            IconButton(
              tooltip: 'Copier le récap du mois',
              icon: const AppIcon(AppIcons.copy, color: AppColors.accent800),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: app.financeMessage(id, _year, _month)));
                widget.nav.showToast('Récap du mois copié');
              },
            ),
          ],
        ),
        Text(
          S.rate == null
              ? 'Aucun tarif : appui long sur le nom › Modifier pour l’ajouter.'
              : S.billing == 'mois'
              ? 'Forfait ${money(S.rate!)} par mois'
              : '${money(S.rate!)} par séance faite',
          style: AppText.body(13, color: AppColors.neutral700),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            SquareIconButton(icon: AppIcons.chevronLeft, tooltip: 'Mois précédent', onPressed: () => _shift(-1)),
            Expanded(
              child: Text(
                capitalized('${monthNames[_month - 1]} $_year'),
                textAlign: TextAlign.center,
                style: AppText.heading(18),
              ),
            ),
            SquareIconButton(icon: AppIcons.chevronRight, tooltip: 'Mois suivant', onPressed: () => _shift(1)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(color: AppColors.divider)),
          child: Column(
            children: [
              if (S.billing != 'mois') line('Séances faites', '${f.done}'),
              line('Dû ce mois', money(f.due)),
              line('Payé ce mois', money(f.paid)),
              const Divider(color: AppColors.divider, height: 14),
              line(f.balance >= 0 ? 'Reste à payer' : 'Avance', money(f.balance.abs()), strong: true),
              if (f.balance != f.left)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Mois précédents compris.', style: AppText.body(12, color: AppColors.neutral700)),
                ),
            ],
          ),
        ),
        for (final p in list)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${money(p.amount)} · ${_dateLabel(p.paidOn)}', style: AppText.body(15)),
                      if (p.note.isNotEmpty) Text(p.note, style: AppText.body(13, color: AppColors.neutral700)),
                    ],
                  ),
                ),
                SquareIconButton(
                  icon: AppIcons.x,
                  tooltip: 'Annuler ce paiement',
                  onPressed: () => _run(() async {
                    final ok = await showConfirmSheet(
                      context,
                      title: 'Annuler ce paiement ?',
                      message: '${money(p.amount)} du ${_dateLabel(p.paidOn)} ne comptera plus dans le bilan.',
                      confirmLabel: 'Annuler le paiement',
                      cancelLabel: 'Garder',
                    );
                    if (ok) {
                      await app.removePayment(id, p.id);
                      widget.nav.showToast('Paiement annulé');
                    }
                  }),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        SecondaryButton(
          label: 'Ajouter un paiement',
          icon: AppIcons.plus,
          onPressed: () => _run(() async {
            final r = await _showPaymentSheet(context, S.first);
            if (r == null) return;
            await app.addPayment(id, amount: r.amount, date: r.date, note: r.note);
            widget.nav.showToast('Paiement de ${money(r.amount)} enregistré');
          }),
        ),
      ],
    );
  }
}

/// « 2026-10-03 » → « 3 oct. 2026 »
String _dateLabel(String iso) {
  final d = DateTime.parse(iso);
  return '${d.day} ${monthShort[d.month - 1]} ${d.year}';
}

/// Montant, date et note d'un paiement. Null si annulé.
Future<({int amount, String date, String note})?> _showPaymentSheet(BuildContext context, String first) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SafeArea(top: false, child: _PaymentSheet(first: first)),
      ),
    );

class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({required this.first});

  final String first;

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime(clock().year, clock().month, clock().day);

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  int? get _value => int.tryParse(_amount.text.replaceAll(RegExp(r'\D'), ''));

  @override
  Widget build(BuildContext context) {
    final v = _value;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Paiement · ${widget.first}', style: AppText.heading(22)),
          const SizedBox(height: 16),
          FieldLabel(
            label: 'Montant (FCFA)',
            child: AppTextField(
              controller: _amount,
              hint: 'Ex. 20000',
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 12),
          FieldLabel(
            label: 'Date',
            child: SizedBox(
              height: 140,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _date,
                maximumDate: DateTime(clock().year + 1),
                onDateTimeChanged: (d) => _date = d,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FieldLabel(
            label: 'Note (facultatif)',
            child: AppTextField(controller: _note, hint: 'Ex. Espèces, Wave…'),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: v == null || v <= 0 ? 'Enregistrer' : 'Enregistrer ${money(v)}',
            onPressed: v == null || v <= 0
                ? null
                : () => Navigator.pop(context, (
                    amount: v,
                    date:
                        '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                    note: _note.text.trim(),
                  )),
          ),
          const SizedBox(height: 8),
          SecondaryButton(label: 'Annuler', onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}
