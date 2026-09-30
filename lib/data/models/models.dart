import 'dart:ui';

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

/// Élève à domicile ou site Succès Group.
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

  /// Numéro WhatsApp en chiffres (ex. 2250700000001).
  final String phone;
  final String phoneLabel;

  bool get isEleve => kind == ServiceKind.eleve;
}

class SchoolClass {
  const SchoolClass({required this.id, required this.name, required this.siteId, this.defaultCount = 0});

  final String id;
  final String name;
  final String siteId;

  /// Séances par défaut dans la préparation d'une semaine.
  final int defaultCount;
}

/// Séance planifiée. Heures en minutes depuis minuit.
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

  /// Issue du planning de base (démo) : conservée d'une génération à l'autre.
  final bool base;

  bool get isRattrapage => kind == SessionKind.rattrapage;

  Session copyWith({
    String? id,
    int? week,
    SessionStatus? status,
    Who? Function()? who,
    String? motif,
    bool? noRedo,
    bool? base,
  }) => Session(
    id: id ?? this.id,
    week: week ?? this.week,
    day: day,
    start: start,
    end: end,
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

/// Séance due (manquée, à rattraper).
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

  /// Date de la séance manquée, ex. « jeu. 1 oct. ».
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

/// Créneau Succès Group choisi dans Préparer. Heures en minutes depuis minuit.
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

  /// Heure de sortie du travail lun.–ven., format « HH:mm » (vide = pas de travail).
  final List<String> off;

  /// Nombre de séances Succès Group placées automatiquement (classes sans [times]).
  final Map<String, int> counts;

  /// Créneaux Succès Group choisis par classe. Présent : remplace [counts].
  final Map<String, List<ClassTime>> times;
  final Map<String, WeekChange> changes;

  /// Rattrapages inclus (absent = inclus).
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

/// Ligne d'historique antérieure à la démo.
class HistoryEntry {
  const HistoryEntry({required this.date, required this.time, required this.status, this.motif});

  final String date;
  final String time;
  final SessionStatus status;
  final String? motif;
}

/// Créneau proposé par le solveur.
class Slot {
  const Slot({required this.week, required this.day, required this.start, required this.end});

  final int week;
  final int day;
  final int start;
  final int end;
}
