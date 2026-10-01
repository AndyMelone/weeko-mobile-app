import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/formats.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/inputs.dart';
import '../shared/screen_header.dart';
import '../shared/session_sheets.dart';
import '../../logic/app_state.dart';

/// Formulaire élève : ajout, ou modification si [initial] est fourni.
class AddStudentForm extends StatefulWidget {
  const AddStudentForm({super.key, required this.onCancel, required this.onSave, this.initial});

  final VoidCallback onCancel;
  final ValueChanged<StudentForm> onSave;
  final StudentForm? initial;

  @override
  State<AddStudentForm> createState() => _AddStudentFormState();
}

class _AddStudentFormState extends State<AddStudentForm> {
  late final _f = widget.initial ?? StudentForm();
  late final _name = TextEditingController(text: _f.name);
  late final _phone = TextEditingController(text: _f.phone);
  late final _rate = TextEditingController(text: _f.rate?.toString() ?? '');
  bool get _editing => widget.initial != null;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _rate.dispose();
    super.dispose();
  }

  void _toggleExcluded(int d) => setState(() {
    if (_f.exDays.contains(d)) {
      _f.exDays.remove(d);
    } else {
      _f.exDays.add(d);
    }
    _f.fixed.removeWhere((x) => x.day == d);
  });

  void _toggleFixed(int d) => setState(() {
    if (_f.fixed.any((x) => x.day == d)) {
      _f.fixed.removeWhere((x) => x.day == d);
    } else if (_f.fixed.length < _f.count) {
      _f.fixed = [..._f.fixed, (day: d, time: d < 5 ? '15:30' : '09:00')]..sort((a, b) => a.day - b.day);
    }
  });

  @override
  Widget build(BuildContext context) {
    final ex = [..._f.exDays]..sort();
    return ScreenBody(
      gap: 20,
      children: [
        Text(_editing ? 'Modifier ${_f.name}' : 'Nouvel élève à domicile', style: AppText.heading(26, height: 1.1)),
        FieldLabel(
          label: "Nom de l'élève",
          child: AppTextField(controller: _name, hint: 'Ex. Koffi Yao', onChanged: (v) => setState(() => _f.name = v)),
        ),
        FieldLabel(
          label: 'WhatsApp du parent',
          child: AppTextField(
            controller: _phone,
            hint: '+225 07 00 00 00 00',
            keyboardType: TextInputType.phone,
            onChanged: (v) => _f.phone = v,
          ),
        ),
        FieldLabel(
          label: 'Séances de 2 h par semaine',
          child: Segmented(
            height: 48,
            fontSize: 16,
            options: [
              for (final n in [1, 2, 3])
                SegOption(
                  label: '$n',
                  selected: _f.count == n,
                  onTap: () => setState(() {
                    _f.count = n;
                    if (_f.fixed.length > n) _f.fixed = _f.fixed.take(n).toList();
                  }),
                ),
            ],
          ),
        ),
        FieldLabel(
          label: 'Jours exclus',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Segmented(
                height: 48,
                fontSize: 13,
                options: [
                  for (var d = 0; d < 7; d++)
                    SegOption(
                      label: dayNamesShort[d],
                      selected: _f.exDays.contains(d),
                      selectedColor: AppColors.neutral900,
                      selectedFg: Colors.white,
                      strike: _f.exDays.contains(d),
                      onTap: () => _toggleExcluded(d),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                ex.isEmpty
                    ? 'Toucher un jour pour l’exclure.'
                    : 'Jamais le ${ex.map((d) => dayNamesLower[d]).join(', ')}.',
                style: AppText.body(12, color: AppColors.neutral700),
              ),
            ],
          ),
        ),
        FieldLabel(
          label: 'Heures exclues (laisser vide si aucune)',
          child: Row(
            children: [
              Expanded(
                child: FieldLabel(
                  label: 'Pas avant',
                  fontSize: 12,
                  gap: 4,
                  child: TimeField(value: _f.notBefore, onChanged: (v) => setState(() => _f.notBefore = v)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FieldLabel(
                  label: 'Pas après',
                  fontSize: 12,
                  gap: 4,
                  child: TimeField(value: _f.notAfter, onChanged: (v) => setState(() => _f.notAfter = v)),
                ),
              ),
            ],
          ),
        ),
        FieldLabel(
          label: 'Jours fixes (séance toujours ce jour-là)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Segmented(
                height: 48,
                fontSize: 13,
                options: [
                  for (var d = 0; d < 7; d++)
                    SegOption(
                      label: dayNamesShort[d],
                      selected: _f.fixed.any((x) => x.day == d),
                      enabled: !_f.exDays.contains(d),
                      fg: _f.exDays.contains(d) ? AppColors.neutral400 : AppColors.text,
                      onTap: () => _toggleFixed(d),
                    ),
                ],
              ),
              for (final x in _f.fixed) ...[
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(minHeight: 52),
                  padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
                  decoration: BoxDecoration(border: Border.all(color: AppColors.divider)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(dayNamesLong[x.day], style: AppText.body(15, weight: FontWeight.w500)),
                      ),
                      Text('début', style: AppText.body(12, color: AppColors.neutral700)),
                      const SizedBox(width: 8),
                      TimeField(
                        value: x.time,
                        width: 112,
                        onChanged: (v) => setState(() {
                          _f.fixed = [for (final y in _f.fixed) y.day == x.day ? (day: y.day, time: v) : y];
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        FieldLabel(
          label: 'Indisponibilités (jour et heures)',
          child: BlocksEditor(blocks: _f.unavailable, onChanged: (b) => setState(() => _f.unavailable = b)),
        ),
        FieldLabel(
          label: 'Tarif',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Segmented(
                height: 44,
                fontSize: 14,
                options: [
                  SegOption(
                    label: 'Par séance',
                    selected: _f.billing == 'seance',
                    onTap: () => setState(() => _f.billing = 'seance'),
                  ),
                  SegOption(
                    label: 'Forfait mensuel',
                    selected: _f.billing == 'mois',
                    onTap: () => setState(() => _f.billing = 'mois'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              AppTextField(
                controller: _rate,
                hint: _f.billing == 'mois' ? 'Montant par mois (FCFA)' : 'Montant par séance (FCFA)',
                keyboardType: TextInputType.number,
                onChanged: (v) => _f.rate = int.tryParse(v.replaceAll(RegExp(r'\D'), '')),
              ),
            ],
          ),
        ),
        Text(
          _editing
              ? 'Les changements s’appliquent à la prochaine génération du planning.'
              : "L'élève reçoit une couleur et sera placé à la prochaine génération du planning.",
          style: AppText.body(13, color: AppColors.neutral700),
        ),
        Row(
          children: [
            Expanded(
              child: SecondaryButton(label: 'Annuler', height: 52, fontSize: 17, onPressed: widget.onCancel),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: PrimaryButton(
                label: _editing ? 'Enregistrer' : "Ajouter l'élève",
                fontSize: 17,
                onPressed: _f.name.trim().isEmpty || _f.unavailable.any((b) => b.end <= b.start)
                    ? null
                    : () => widget.onSave(_f),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
