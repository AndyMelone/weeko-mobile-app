import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../utils/formats.dart';
import 'buttons.dart';

/// Option d'un segmenté ou d'une rangée de jours.
class SegOption {
  const SegOption({
    required this.label,
    required this.selected,
    required this.onTap,
    this.sub,
    this.selectedColor = AppColors.accent,
    this.selectedFg = AppColors.bg,
    this.fg = AppColors.text,
    this.strike = false,
    this.enabled = true,
  });

  final String label;
  final String? sub;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;
  final Color selectedFg;
  final Color fg;
  final bool strike;
  final bool enabled;
}

/// Segmenté à colonnes égales (Normal / 1 séance / Absent, jours de la semaine…).
class Segmented extends StatelessWidget {
  const Segmented({super.key, required this.options, this.height = 44, this.fontSize = 14});

  final List<SegOption> options;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: AppColors.divider)),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < options.length; i++)
              Expanded(
                child: _SegCell(option: options[i], first: i == 0, height: height, fontSize: fontSize),
              ),
          ],
        ),
      ),
    );
  }
}

class _SegCell extends StatelessWidget {
  const _SegCell({required this.option, required this.first, required this.height, required this.fontSize});

  final SegOption option;
  final bool first;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final o = option;
    final fg = o.selected ? o.selectedFg : o.fg;
    return Tap(
      onTap: o.enabled ? o.onTap : null,
      color: o.selected ? o.selectedColor : Colors.transparent,
      border: first ? null : const Border(left: BorderSide(color: AppColors.divider)),
      constraints: BoxConstraints(minHeight: height),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              o.label,
              textAlign: TextAlign.center,
              style: AppText.body(fontSize, color: fg, decoration: o.strike ? TextDecoration.lineThrough : null),
            ),
            if (o.sub != null) Text(o.sub!, style: AppText.heading(17, color: fg)),
          ],
        ),
      ),
    );
  }
}

/// Champ heure (équivalent `input type=time`) : ouvre deux roues heures / minutes.
class TimeField extends StatelessWidget {
  const TimeField({super.key, required this.value, required this.onChanged, this.width, this.placeholder = '--:--'});

  /// Format « HH:mm », vide = aucune valeur.
  final String value;
  final ValueChanged<String> onChanged;
  final double? width;
  final String placeholder;

  Future<void> _pick(BuildContext context) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(),
      builder: (_) => _TimeWheels(initial: parseTime(value) ?? 900),
    );
    if (picked != null) onChanged(toHhMm(picked));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Tap(
        onTap: () => _pick(context),
        color: AppColors.surface,
        border: Border.all(color: AppColors.divider),
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            value.isEmpty ? placeholder : value,
            style: AppText.body(16, color: value.isEmpty ? AppColors.neutral600 : AppColors.text),
          ),
        ),
      ),
    );
  }
}

/// Champ texte au style `.input`.
class AppTextField extends StatelessWidget {
  const AppTextField({super.key, required this.controller, this.hint, this.keyboardType, this.onChanged});

  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: AppColors.divider),
    );
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: AppText.body(16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppText.body(16, color: AppColors.neutral600),
        filled: true,
        fillColor: AppColors.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.accent)),
      ),
    );
  }
}

/// Libellé de champ (13px neutral-700) au-dessus d'un contrôle.
class FieldLabel extends StatelessWidget {
  const FieldLabel({super.key, required this.label, required this.child, this.fontSize = 13, this.gap = 6});

  final String label;
  final Widget child;
  final double fontSize;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: AppText.body(fontSize, color: AppColors.neutral700)),
        SizedBox(height: gap),
        child,
      ],
    );
  }
}

/// Roues heures (0–23) et minutes (0–59), en boucle.
class _TimeWheels extends StatefulWidget {
  const _TimeWheels({required this.initial});

  /// Minutes depuis minuit.
  final int initial;

  @override
  State<_TimeWheels> createState() => _TimeWheelsState();
}

class _TimeWheelsState extends State<_TimeWheels> {
  late int _hour = widget.initial ~/ 60;
  late int _minute = widget.initial % 60;
  late final _hours = FixedExtentScrollController(initialItem: _hour);
  late final _minutes = FixedExtentScrollController(initialItem: _minute);

  @override
  void dispose() {
    _hours.dispose();
    _minutes.dispose();
    super.dispose();
  }

  Widget _wheel(FixedExtentScrollController ctrl, int count, ValueChanged<int> onSelected) => SizedBox(
    width: 90,
    child: CupertinoPicker(
      scrollController: ctrl,
      itemExtent: 44,
      looping: true,
      selectionOverlay: const CupertinoPickerDefaultSelectionOverlay(background: Color(0x1F5980A6)),
      onSelectedItemChanged: (i) => onSelected(i % count),
      children: [
        for (var i = 0; i < count; i++) Center(child: Text(i.toString().padLeft(2, '0'), style: AppText.heading(26))),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Annuler', style: AppText.body(16, color: AppColors.neutral700)),
                ),
                Expanded(
                  child: Text('Heure', textAlign: TextAlign.center, style: AppText.heading(18)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, _hour * 60 + _minute),
                  child: Text('OK', style: AppText.heading(18, color: AppColors.accent700)),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 220,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _wheel(_hours, 24, (h) => _hour = h),
                Text(':', style: AppText.heading(26)),
                _wheel(_minutes, 60, (m) => _minute = m),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
