import 'dart:ui';

import '../models/models.dart';

// Conversion des réponses de weeko-api vers les modèles de l'app.

typedef Json = Map<String, dynamic>;

/// « #9B4630 » → Color(0xFF9B4630).
Color colorOf(String hex) => Color(int.parse(hex.replaceFirst('#', ''), radix: 16) | 0xFF000000);

Service serviceFromJson(Json j) => Service(
  id: j['id'],
  name: j['name'],
  first: j['first'],
  code: j['code'],
  color: colorOf(j['color']),
  kind: ServiceKind.values.byName(j['kind']),
  perWeek: j['perWeek'],
  noWeekend: j['noWeekend'],
  exDays: List<int>.from(j['exDays']),
  notBefore: j['notBefore'],
  notAfter: j['notAfter'],
  fixed: [for (final f in j['fixed'] as List) FixedSlot(day: f['day'], start: f['start'])],
  phone: j['phone'],
  phoneLabel: j['phoneLabel'],
);

SchoolClass classFromJson(Json j) =>
    SchoolClass(id: j['id'], name: j['name'], siteId: j['siteId'], defaultCount: j['defaultCount'] ?? 0);

Session sessionFromJson(Json j) => Session(
  id: j['id'],
  week: j['week'],
  day: j['day'],
  start: j['start'],
  end: j['end'],
  svc: j['svc'],
  cls: j['cls'],
  status: SessionStatus.values.byName(j['status']),
  kind: SessionKind.values.byName(j['kind']),
  dueId: j['dueId'],
  who: j['who'] == null ? null : Who.values.byName(j['who']),
  motif: j['motif'] ?? '',
  noRedo: j['noRedo'] ?? false,
  fixed: j['fixed'] ?? false,
  base: j['base'] ?? false,
);

Due dueFromJson(Json j) => Due(
  id: j['id'],
  svc: j['svc'],
  cls: j['cls'],
  from: j['from'],
  who: Who.values.byName(j['who']),
  motif: j['motif'],
  placedSession: j['placedSession'],
  done: j['done'] ?? false,
  sourceId: j['sourceId'],
);

WeekPrep prepFromJson(Json j) => WeekPrep(
  off: List<String>.from(j['off']),
  counts: Map<String, int>.from(j['counts'] ?? const {}),
  times: {
    for (final e in (j['times'] as Map? ?? const {}).entries)
      e.key as String: [
        for (final t in e.value as List) (day: t['day'] as int, start: t['start'] as int, end: t['end'] as int),
      ],
  },
  changes: {
    for (final e in (j['changes'] as Map? ?? const {}).entries) e.key as String: WeekChange.values.byName(e.value),
  },
  include: Map<String, bool>.from(j['include'] ?? const {}),
);

Json prepToJson(WeekPrep p) => {
  'off': p.off,
  'counts': p.counts,
  'times': {
    for (final e in p.times.entries)
      e.key: [
        for (final t in e.value) {'day': t.day, 'start': t.start, 'end': t.end},
      ],
  },
  'changes': {for (final e in p.changes.entries) e.key: e.value.name},
  'include': p.include,
};

HistoryEntry historyFromJson(Json j) =>
    HistoryEntry(date: j['date'], time: j['time'], status: SessionStatus.values.byName(j['status']), motif: j['motif']);
