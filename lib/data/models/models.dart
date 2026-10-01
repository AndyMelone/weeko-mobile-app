import 'dart:ui';

import '../../core/utils/formats.dart';

enum ServiceKind { eleve, site }

enum SessionStatus { prevue, faite, manquee, rattrapee }

enum SessionKind { normal, rattrapage }

enum Who { moi, eleve }

enum WeekChange { normal, une, absent }

class FixedSlot {
  const FixedSlot({required this.day, required this.start});

  final int day;
  final int start;
}

class TimeBlock {
  const TimeBlock({required this.day, required this.start, required this.end});

  final int day;
  final int start;
  final int end;

  String get label => start <= 0
      ? 'avant ${fmt(end)}'
      : end >= 1440
      ? 'après ${fmt(start)}'
      : range(start, end);
}

class Service {
  const Service({
    required this.id,
    required this.name,
    required this.code,
    required this.color,
    required this.kind,
    String? first,
    this.perWeek = 0,
    this.noWeekend = false,
    this.exDays = const [],
    this.notBefore,
    this.notAfter,
    this.fixed = const [],
    this.unavailable = const [],
    this.rate,
    this.billing = 'seance',
    this.phone = '',
    this.phoneLabel = '',
  }) : first = first ?? name;

  final String id;
  final String name;
  final String first;
  final String code;
  final Color color;
  final ServiceKind kind;
  final int perWeek;
  final bool noWeekend;
  final List<int> exDays;
  final int? notBefore;
  final int? notAfter;
  final List<FixedSlot> fixed;
  final List<TimeBlock> unavailable;

  /// Tarif en FCFA : par séance faite (billing « seance ») ou forfait mensuel (« mois »).
  final int? rate;
  final String billing;

  final String phone;
  final String phoneLabel;

  bool get isEleve => kind == ServiceKind.eleve;
}

class SchoolClass {
  const SchoolClass({required this.id, required this.name, required this.siteId, this.defaultCount = 0});

  final String id;
  final String name;
  final String siteId;

  final int defaultCount;
}

class Session {
  const Session({
    required this.id,
    required this.week,
    required this.day,
    required this.start,
    required this.end,
    required this.svc,
    this.cls,
    this.status = SessionStatus.prevue,
    this.kind = SessionKind.normal,
    this.dueId,
    this.who,
    this.motif = '',
    this.noRedo = false,
    this.fixed = false,
    this.base = false,
  });

  final String id;
  final int week;
  final int day;
  final int start;
  final int end;
  final String svc;
  final String? cls;
  final SessionStatus status;
  final SessionKind kind;
  final String? dueId;
  final Who? who;
  final String motif;
  final bool noRedo;
  final bool fixed;

  final bool base;

  bool get isRattrapage => kind == SessionKind.rattrapage;

  Session copyWith({
    String? id,
    int? week,
    int? day,
    int? start,
    int? end,
    SessionStatus? status,
    Who? Function()? who,
    String? motif,
    bool? noRedo,
    bool? base,
  }) => Session(
    id: id ?? this.id,
    week: week ?? this.week,
    day: day ?? this.day,
    start: start ?? this.start,
    end: end ?? this.end,
    svc: svc,
    cls: cls,
    status: status ?? this.status,
    kind: kind,
    dueId: dueId,
    who: who != null ? who() : this.who,
    motif: motif ?? this.motif,
    noRedo: noRedo ?? this.noRedo,
    fixed: fixed,
    base: base ?? this.base,
  );
}

class Due {
  const Due({
    required this.id,
    required this.svc,
    this.cls,
    required this.from,
    required this.who,
    required this.motif,
    this.placedSession,
    this.done = false,
    this.sourceId,
  });

  final String id;
  final String svc;
  final String? cls;

  final String from;
  final Who who;
  final String motif;
  final String? placedSession;
  final bool done;
  final String? sourceId;

  Due copyWith({String? Function()? placedSession, bool? done}) => Due(
    id: id,
    svc: svc,
    cls: cls,
    from: from,
    who: who,
    motif: motif,
    placedSession: placedSession != null ? placedSession() : this.placedSession,
    done: done ?? this.done,
    sourceId: sourceId,
  );
}

typedef ClassTime = ({int day, int start, int end});

class WeekPrep {
  WeekPrep({
    required this.off,
    required this.counts,
    Map<String, List<ClassTime>>? times,
    Map<String, WeekChange>? changes,
    Map<String, bool>? include,
  }) : times = times ?? {},
       changes = changes ?? {},
       include = include ?? {};

  final List<String> off;

  final Map<String, int> counts;

  final Map<String, List<ClassTime>> times;
  final Map<String, WeekChange> changes;

  final Map<String, bool> include;

  WeekPrep copy() => WeekPrep(
    off: [...off],
    counts: {...counts},
    times: {
      for (final e in times.entries) e.key: [...e.value],
    },
    changes: {...changes},
    include: {...include},
  );
}

class HistoryEntry {
  const HistoryEntry({required this.date, required this.time, required this.status, this.motif});

  final String date;
  final String time;
  final SessionStatus status;
  final String? motif;
}

class Slot {
  const Slot({required this.week, required this.day, required this.start, required this.end});

  final int week;
  final int day;
  final int start;
  final int end;
}

/// Paiement reçu d'un parent (FCFA). [paidOn] : « YYYY-MM-DD ».
class Payment {
  const Payment({
    required this.id,
    required this.serviceId,
    required this.amount,
    required this.paidOn,
    this.note = '',
  });

  final String id;
  final String serviceId;
  final int amount;
  final String paidOn;
  final String note;
}
