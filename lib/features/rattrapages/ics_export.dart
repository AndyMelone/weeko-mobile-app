import 'dart:convert';

import 'package:share_plus/share_plus.dart';

import '../../core/utils/formats.dart';
import '../../data/models/models.dart';
import '../../logic/app_state.dart';

/// Partage la séance en .ics (fuseau Africa/Abidjan, rappel 45 min avant),
/// pour l'ajouter à l'agenda du téléphone.
Future<void> shareSessionIcs(AppState app, Session s) async {
  final dt = dateOf(s.week, s.day);
  String p(int n) => n.toString().padLeft(2, '0');
  String stamp(int m) => '${dt.year}${p(dt.month)}${p(dt.day)}T${p(m ~/ 60)}${p(m % 60)}00';
  final site = app.svc(s.svc).name;
  final title =
      '${s.isRattrapage ? 'Rattrapage · ' : ''}${app.titleOf(s)}${s.cls != null ? ' · Succès Group $site' : ''}';
  final ics = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Repetiteur//FR',
    'BEGIN:VEVENT',
    'UID:${s.id}@repetiteur',
    'DTSTART;TZID=Africa/Abidjan:${stamp(s.start)}',
    'DTEND;TZID=Africa/Abidjan:${stamp(s.end)}',
    'SUMMARY:$title',
    'LOCATION:${s.cls != null ? 'Succès Group $site' : 'Domicile de l’élève'}',
    'BEGIN:VALARM',
    'TRIGGER:-PT45M',
    'ACTION:DISPLAY',
    'DESCRIPTION:$title',
    'END:VALARM',
    'END:VEVENT',
    'END:VCALENDAR',
  ].join('\r\n');
  final fileName = '${title.replaceAll(RegExp(r'[^\wÀ-ÿ -]'), '').trim()}.ics';
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(utf8.encode(ics), mimeType: 'text/calendar', name: fileName)],
      fileNameOverrides: [fileName],
    ),
  );
}
