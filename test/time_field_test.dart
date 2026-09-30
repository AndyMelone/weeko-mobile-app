import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weeko/core/widgets/inputs.dart';

void main() {
  testWidgets('les roues heures / minutes renvoient « HH:mm »', (tester) async {
    String? value;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimeField(value: '15:00', onChanged: (v) => value = v),
        ),
      ),
    );
    await tester.tap(find.text('15:00'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoPicker), findsNWidgets(2));

    await tester.drag(find.byType(CupertinoPicker).first, const Offset(0, -44));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CupertinoPicker).last, const Offset(0, -44 * 30));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(value, '16:30');
  });

  testWidgets('Annuler ne change rien', (tester) async {
    String? value;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimeField(value: '', onChanged: (v) => value = v),
        ),
      ),
    );
    await tester.tap(find.text('--:--'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(value, isNull);
  });
}
