import 'dart:async';
import 'dart:math';

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/formats.dart';
import '../data/api/api_client.dart';
import '../data/api/json.dart';
import '../data/models/models.dart';

const _dayEnd = 1290;

class RattItem {
  const RattItem({
    required this.key,
    required this.svc,
    this.cls,
    this.due,
    required this.week,
    this.placedSession,
    required this.title,
    required this.detail,
    this.placed,
  });

  final String key;
  final String svc;
  final String? cls;
  final Due? due;
  final int week;
  final Session? placedSession;
  final String title;
  final String detail;

  final String? placed;

  bool get isDue => due != null;
}

sealed class SlotChoice {
  const SlotChoice();
}

class ProposalChoice extends SlotChoice {
  const ProposalChoice(this.index);
  final int index;
}

/// Créneau précis saisi à la main (ex. donné par le président de Succès Group).
class SlotPick extends SlotChoice {
  const SlotPick(this.slot);
  final Slot slot;
}

class DayChoice extends SlotChoice {
  const DayChoice(this.day);
  final int day;
}

class PointerDraft {
  const PointerDraft({required this.missed, this.who, this.motif = '', this.redo = true});

  final bool missed;
  final Who? who;
  final String motif;
  final bool redo;

  PointerDraft copyWith({bool? missed, Who? who, String? motif, bool? redo}) => PointerDraft(
    missed: missed ?? this.missed,
    who: who ?? this.who,
    motif: motif ?? this.motif,
    redo: redo ?? this.redo,
  );
}

class StudentForm {
  StudentForm();

  /// Formulaire prérempli avec la fiche d'un élève (modification).
  StudentForm.of(Service s)
    : name = s.name,
      phone = s.phoneLabel == 'numéro à compléter' ? '' : s.phoneLabel,
      count = s.perWeek,
      exDays = {
        ...s.exDays,
        if (s.noWeekend) ...[5, 6],
      }.toList()..sort(),
      notBefore = s.notBefore == null ? '' : toHhMm(s.notBefore!),
      notAfter = s.notAfter == null ? '' : toHhMm(s.notAfter!),
      fixed = [for (final f in s.fixed) (day: f.day, time: toHhMm(f.start))],
      unavailable = [...s.unavailable],
      rate = s.rate,
      billing = s.billing;

  String name = '';
  String phone = '';
  int count = 2;
  List<int> exDays = [];
  String notBefore = '';
  String notAfter = '';

  List<({int day, String time})> fixed = [];
  List<TimeBlock> unavailable = [];
  int? rate;
  String billing = 'seance';

  Json toJson() => {
    'name': name.trim(),
    'phone': phone,
    'count': count,
    'exDays': exDays,
    'notBefore': notBefore,
    'notAfter': notAfter,
    'fixed': [
      for (final x in fixed) {'day': x.day, 'time': x.time},
    ],
    'unavailable': blocksToJson(unavailable),
    'rate': rate,
    'billing': billing,
  };
}

enum LoadStatus { loading, ready, error }

const _defaultOff = ['15:00', '15:00', '18:00', '15:00', '16:00'];

class AppState extends ChangeNotifier {
  AppState(this.api, {this.onError});

  final ApiClient api;

  final void Function(String message)? onError;

  LoadStatus status = LoadStatus.loading;
  String? error;

  final Map<String, Service> services = {};
  final Map<String, SchoolClass> classes = {};
  final Map<String, List<HistoryEntry>> history = {};
  List<String> students = [];
  List<Session> sessions = [];
  List<Due> dues = [];
  final Map<int, WeekPrep> preps = {};
  final Set<int> generated = {};

  bool travelEnabled = false;

  List<TimeBlock> tutorUnavailable = [];

  /// Paiements reçus (tous élèves), plus récents d'abord.
  List<Payment> payments = [];

  /// Jeton du flux agenda, null s'il n'est pas activé.
  String? calendarToken;

  // ─── Hors ligne ───────────────────────────────────────────────

  /// Pas de réseau : l'app affiche le dernier planning enregistré.
  bool offline = false;

  /// Date du planning affiché quand on est hors ligne.
  DateTime? cachedAt;

  /// Pointages faits hors ligne, envoyés au retour du réseau.
  List<Json> pendingPointers = [];

  Timer? _retry;

  static const _kState = 'weeko.state', _kStateAt = 'weeko.stateAt', _kQueue = 'weeko.queue';

  Future<void> load() async {
    try {
      await _replayQueue();
      final j = await api.get('/state') as Json;
      _apply(j);
      status = LoadStatus.ready;
      error = null;
      offline = false;
      _retry?.cancel();
      _retry = null;
      cachedAt = DateTime.now();
      await _saveCache(j);
    } on ApiException catch (e) {
      if (e.isNetwork) {
        if (status != LoadStatus.ready) await _loadCache();
        if (status == LoadStatus.ready) {
          offline = true;
          error = null;
          // Nouvelle tentative régulière tant que le réseau manque.
          _retry ??= Timer.periodic(const Duration(seconds: 30), (_) => load().catchError((_) {}));
          notifyListeners();
          return;
        }
      }
      if (status != LoadStatus.ready) status = LoadStatus.error;
      error = e.message;
      if (status == LoadStatus.ready) rethrow;
    }
    notifyListeners();
  }

  Future<void> _saveCache(Json j) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kState, jsonEncode(j));
      await prefs.setString(_kStateAt, DateTime.now().toIso8601String());
    } catch (_) {}
  }

  /// Dernier planning enregistré + pointages en attente, appliqués localement.
  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kState);
      if (raw == null) return;
      _apply(jsonDecode(raw) as Json);
      cachedAt = DateTime.tryParse(prefs.getString(_kStateAt) ?? '');
      pendingPointers = await _readQueue(prefs);
      for (final q in pendingPointers) {
        _pointLocally(q['id'] as String, q['body'] as Json);
      }
      status = LoadStatus.ready;
    } catch (_) {}
  }

  Future<List<Json>> _readQueue(SharedPreferences prefs) async => [
    for (final x in jsonDecode(prefs.getString(_kQueue) ?? '[]') as List) x as Json,
  ];

  Future<void> _saveQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kQueue, jsonEncode(pendingPointers));
    } catch (_) {}
  }

  /// Envoie les pointages faits hors ligne, dans l'ordre. S'arrête au premier échec réseau.
  Future<void> _replayQueue() async {
    if (pendingPointers.isEmpty) {
      try {
        pendingPointers = await _readQueue(await SharedPreferences.getInstance());
      } catch (_) {}
    }
    while (pendingPointers.isNotEmpty) {
      final q = pendingPointers.first;
      try {
        await api.post('/sessions/${Uri.encodeComponent(q['id'] as String)}/pointer', q['body']);
      } on ApiException catch (e) {
        if (e.isNetwork) rethrow;
        // Refusé par le serveur (séance supprimée…) : abandonné.
        onError?.call('Pointage hors ligne non enregistré : ${e.message}');
      }
      pendingPointers = pendingPointers.sublist(1);
      await _saveQueue();
    }
  }

  /// Reflet local d'un pointage (statut de la séance) en attendant le serveur.
  void _pointLocally(String id, Json body) {
    final missed = body['missed'] == true;
    sessions = [
      for (final x in sessions)
        x.id != id
            ? x
            : x.copyWith(
                status: missed
                    ? SessionStatus.manquee
                    : (x.isRattrapage ? SessionStatus.rattrapee : SessionStatus.faite),
                who: () => missed && body['who'] != null ? Who.values.byName(body['who']) : null,
                motif: missed ? (body['motif'] ?? '') : '',
                noRedo: missed && body['redo'] == false,
              ),
    ];
  }

  Future<void> retry() {
    status = LoadStatus.loading;
    notifyListeners();
    return load();
  }

  void _apply(Json j) {
    services
      ..clear()
      ..addEntries([for (final x in j['services'] as List) serviceFromJson(x)].map((s) => MapEntry(s.id, s)));
    classes
      ..clear()
      ..addEntries([for (final x in j['classes'] as List) classFromJson(x)].map((c) => MapEntry(c.id, c)));
    students = List<String>.from(j['students']);
    sessions = [for (final x in j['sessions'] as List) sessionFromJson(x)];
    dues = [for (final x in j['dues'] as List) dueFromJson(x)];
    final local = {for (final w in _prepTimers.keys) w: preps[w]!};
    preps
      ..clear()
      ..addAll({for (final e in (j['preps'] as Map).entries) int.parse(e.key): prepFromJson(e.value)})
      ..addAll(local);
    generated
      ..clear()
      ..addAll(List<int>.from(j['generated']));
    travelEnabled = (j['settings'] as Map?)?['travel'] == true;
    tutorUnavailable = blocksFromJson((j['settings'] as Map?)?['unavailable']);
    calendarToken = (j['settings'] as Map?)?['calendarToken'];
    payments = [for (final x in (j['payments'] as List? ?? const [])) paymentFromJson(x)];
    history
      ..clear()
      ..addAll({
        for (final e in (j['history'] as Map? ?? const {}).entries)
          e.key as String: [for (final h in e.value as List) historyFromJson(h)],
      });
  }

  bool busy = false;

  Future<Json> _mutate(Future<dynamic> Function() call) async {
    if (busy) throw const ApiException('Opération en cours…');
    busy = true;
    notifyListeners();
    try {
      final res = await call();
      await load();
      return res is Json ? res : const {};
    } on ApiException catch (e) {
      if (!e.isNetwork) rethrow;
      offline = true;
      throw const ApiException('Hors ligne : action possible dès le retour du réseau.');
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Service svc(String id) => services[id]!;
  bool isEleve(String svcId) => svc(svcId).isEleve;

  List<Session> week(int w, [List<Session>? ss]) => (ss ?? sessions).where((s) => s.week == w).toList();

  WeekPrep defaultPrep() => WeekPrep(
    off: [..._defaultOff],
    counts: {for (final c in classes.values) c.id: c.defaultCount},
    times: {for (final c in classes.values) c.id: []},
  );

  WeekPrep prepOf(int w) => preps[w] ?? defaultPrep();

  int? off(int day, int w) => day < 5 ? parseTime(prepOf(w).off[day]) : null;

  List<Session> get decided => week(currentWeek).where((s) => s.base && s.fixed).toList();

  Session? sessionById(String? id) => id == null ? null : sessions.where((s) => s.id == id).firstOrNull;

  String titleOf(Session s) => s.cls != null ? classes[s.cls]!.name : svc(s.svc).name;

  String whoLabel(Due u) => u.who == Who.moi ? 'moi absent' : (isEleve(u.svc) ? 'élève absent' : 'classe absente');

  int travel(({String svc}) a, ({String svc}) b) {
    if (!travelEnabled) return 0;
    if (isEleve(a.svc) && isEleve(b.svc)) return 10;
    if (a.svc == b.svc && !isEleve(a.svc)) return 0;
    return 30;
  }

  int get fromWork => travelEnabled ? 30 : 0;

  /// Règle bloquante : un élève n'a jamais deux séances le même jour.
  /// Retourne le motif du refus, null si la semaine [ss] est valide.
  String? sameDayConflict(List<Session> ss) {
    final seen = <(String, int)>{};
    for (final s in ss) {
      if (!isEleve(s.svc) || s.status == SessionStatus.manquee) continue;
      if (!seen.add((s.svc, s.day))) {
        return 'Impossible : ${svc(s.svc).first} aurait deux séances le ${dayNamesLower[s.day]}.';
      }
    }
    return null;
  }

  /// Règles non respectées par la séance [s] dans la semaine [ss] (aperçu modifié).
  /// Ce ne sont que des avertissements : la séance peut être validée quand même.
  List<String> issuesOf(Session s, List<Session> ss, int w) {
    final out = <String>[];
    final d = s.day;
    if (s.end > _dayEnd) out.add('Finit après 21h30');
    final o = off(d, w);
    if (o != null && s.start < o + fromWork) out.add('Avant la fin du travail (${fmt(o)})');
    for (final x in ss) {
      if (x.id == s.id || x.day != d || x.status == SessionStatus.manquee) continue;
      if (s.start < x.end && x.start < s.end) {
        out.add('Chevauche ${titleOf(x)} (${range(x.start, x.end)})');
      } else {
        final t = s.start >= x.end ? travel((svc: x.svc), (svc: s.svc)) : travel((svc: s.svc), (svc: x.svc));
        if (s.start < x.end + t && x.start < s.end + t) out.add('Trajet trop court avec ${titleOf(x)}');
      }
    }
    for (final b in blocksOn(s.svc, d)) {
      if (s.start < b.end && b.start < s.end) out.add('Indisponible le ${dayNamesLower[d]} ${b.label}');
    }
    final S = svc(s.svc);
    if (S.isEleve && !s.isRattrapage) {
      if (S.noWeekend && d >= 5) out.add('${S.first} ne prend pas cours le week-end');
      if (S.exDays.contains(d)) out.add('${S.first} ne prend jamais cours le ${dayNamesLower[d]}');
      if (S.notBefore != null && s.start < S.notBefore!) out.add('Avant ${fmt(S.notBefore!)}');
      if (S.notAfter != null && s.end > S.notAfter!) out.add('Après ${fmt(S.notAfter!)}');
      final next = ss.where((x) => x.id != s.id && x.svc == s.svc && !x.isRattrapage && (x.day - d).abs() == 1);
      for (final x in next) {
        out.add('${S.first} a aussi cours ${dayNamesLower[x.day]} : jamais deux jours de suite');
      }
    }
    return out;
  }

  Future<void> setTravel(bool v) => _mutate(() => api.patch('/settings', {'travel': v}));

  List<TimeBlock> blocksOn(String svcId, int d) =>
      [...tutorUnavailable, ...svc(svcId).unavailable].where((b) => b.day == d).toList();

  bool _blocked(String svcId, int d, int st, int en) => blocksOn(svcId, d).any((b) => st < b.end && en > b.start);

  Slot? slotOn(String svcId, int d, List<Session> ss, int w) {
    final o = off(d, w);
    final day = ss.where((s) => s.day == d && s.status != SessionStatus.manquee).toList()
      ..sort((a, b) => a.start - b.start);
    final S = svc(svcId);
    if (S.isEleve) {
      if (S.noWeekend && d >= 5) return null;
      if (S.exDays.contains(d)) return null;
      if (ss.any((s) => s.svc == svcId && s.status != SessionStatus.manquee && (s.day - d).abs() <= 1)) return null;
      final earliest = max(o != null ? o + fromWork : 480, S.notBefore ?? 0);
      final latest = min(_dayEnd, S.notAfter ?? _dayEnd);
      final cands = [
        earliest,
        ...day.map((s) => s.end + travel((svc: s.svc), (svc: svcId))),
        ...blocksOn(svcId, d).map((b) => b.end),
      ]..sort();
      for (final c in cands) {
        final st = max(c, earliest), en = st + 120;
        if (en > latest || _blocked(svcId, d, st, en)) continue;
        if (day.any((s) => !isEleve(s.svc) && s.start < st)) continue;
        final fits = day.every((s) {
          final t = travel((svc: s.svc), (svc: svcId));
          return en + t <= s.start || st >= s.end + t;
        });
        if (fits) return Slot(week: w, day: d, start: st, end: en);
      }
      return null;
    }
    final wins = d < 5 ? const [(1080, 1230)] : const [(480, 720), (840, 1080)];
    for (final (st, en) in wins) {
      if (o != null && o + fromWork > st) continue;
      if (_blocked(svcId, d, st, en)) continue;
      final fits = day.every((s) {
        final t = travelEnabled && s.svc != svcId ? 30 : 0;
        return s.end + t <= st || (!isEleve(s.svc) && en + t <= s.start);
      });
      if (fits) return Slot(week: w, day: d, start: st, end: en);
    }
    return null;
  }

  List<Slot> slots(String svcId, {int? onlyDay, int w = 0, List<Session>? ss}) {
    ss ??= week(w);
    return [
      for (var d = 0; d < 7; d++)
        if (onlyDay == null || d == onlyDay) ?slotOn(svcId, d, ss, w),
    ];
  }

  List<Slot> _nextWeekFallback(String svcId, int w0) {
    final w = w0 + 1;
    if (!isEleve(svcId)) {
      return [
        Slot(week: w, day: 0, start: 1080, end: 1230),
        Slot(week: w, day: 1, start: 1080, end: 1230),
        Slot(week: w, day: 5, start: 480, end: 720),
      ].where((s) => !_blocked(svcId, s.day, s.start, s.end)).toList();
    }
    final out = <Slot>[];
    final sunday = week(w0).any((s) => s.svc == svcId && s.day == 6);
    for (var d = 0; d < 5 && out.length < 2; d++) {
      if (d == 0 && sunday) continue;
      final st = (off(d, w) ?? 900) + fromWork;
      if (svc(svcId).exDays.contains(d) || _blocked(svcId, d, st, st + 120)) continue;
      if (st + 120 <= _dayEnd) out.add(Slot(week: w, day: d, start: st, end: st + 120));
    }
    return out;
  }

  List<Slot> proposals(RattItem it) {
    final w0 = it.week;
    final a = slots(it.svc, w: w0);
    final b = generated.contains(w0 + 1) ? slots(it.svc, w: w0 + 1) : _nextWeekFallback(it.svc, w0);
    return [...a, ...b].take(3).toList();
  }

  String reason(RattItem it, int d) {
    final S = svc(it.svc);
    if (S.isEleve) {
      if (S.noWeekend && d >= 5) return '${S.first} ne prend pas de cours le week-end.';
      if (S.exDays.contains(d)) return '${S.first} ne prend jamais cours le ${dayNamesLower[d]}.';
      if (week(it.week).any((s) => s.svc == it.svc && s.status != SessionStatus.manquee && (s.day - d).abs() <= 1)) {
        return '${S.first} a déjà cours ce jour-là, la veille ou le lendemain.';
      }
      final blocks = blocksOn(it.svc, d);
      if (blocks.isNotEmpty) {
        return 'Pas de créneau de 2 h libre ce jour-là (indisponible ${blocks.map((b) => b.label).join(', ')}).';
      }
      return travelEnabled
          ? 'Pas de créneau de 2 h libre ce jour-là (trajets, fin à 21h30).'
          : 'Pas de créneau de 2 h libre ce jour-là (fin à 21h30).';
    }
    return 'Pas de créneau Succès Group libre ce jour-là.';
  }

  List<RattItem> items() {
    final out = <RattItem>[];
    for (final u in dues.where((u) => !u.done)) {
      final ps = sessionById(u.placedSession);
      out.add(
        RattItem(
          key: u.id,
          svc: u.svc,
          cls: u.cls,
          due: u,
          week: currentWeek,
          placedSession: ps,
          title: u.cls != null ? '${classes[u.cls]!.name} · ${svc(u.svc).name}' : svc(u.svc).name,
          detail: 'Manquée ${u.from} · ${whoLabel(u)}${u.motif.isNotEmpty ? ' · ${u.motif}' : ''}',
          placed: ps == null ? null : '${dayShort(ps.week, ps.day)} · ${range(ps.start, ps.end)}',
        ),
      );
    }
    return [...out.where((i) => i.placed == null), ...out.where((i) => i.placed != null)];
  }

  int get todoCount => items().where((i) => i.placed == null).length;

  Slot? resolveChoice(RattItem it, SlotChoice? choice) => switch (choice) {
    ProposalChoice(:final index) => proposals(it).elementAtOrNull(index),
    DayChoice(:final day) => slots(it.svc, onlyDay: day, w: it.week).firstOrNull,
    SlotPick(:final slot) => slot,
    null => null,
  };

  Future<String?> place(RattItem it, SlotChoice? choice) async {
    final body = switch (choice) {
      ProposalChoice(:final index) => {'proposal': index},
      DayChoice(:final day) => {'day': day},
      SlotPick(:final slot) => {'slot': slotToJson(slot)},
      null => null,
    };
    if (body == null) return null;
    await flushPrep();
    final res = await _mutate(() => api.post('/rattrapages/${Uri.encodeComponent(it.key)}/place', body));
    return res['message'] as String;
  }

  final Map<int, Timer> _prepTimers = {};

  void updatePrep(int w, void Function(WeekPrep p) fn) {
    fn(preps.putIfAbsent(w, defaultPrep));
    notifyListeners();
    _prepTimers[w]?.cancel();
    _prepTimers[w] = Timer(const Duration(milliseconds: 400), () => _sendPrep(w));
  }

  Future<void> _sendPrep(int w) async {
    _prepTimers.remove(w)?.cancel();
    final p = preps[w];
    if (p == null) return;
    try {
      await api.patch('/weeks/$w/prep', prepToJson(p));
    } on ApiException catch (e) {
      onError?.call('Préparation non enregistrée : ${e.message}');
    }
  }

  Future<void> flushPrep() => Future.wait([for (final w in _prepTimers.keys.toList()) _sendPrep(w)]);

  Future<({String message, List<Session> sessions})> preview(int w) async {
    await flushPrep();
    final res = await api.post('/weeks/$w/preview') as Json;
    return (message: res['message'] as String, sessions: [for (final x in res['sessions'] as List) sessionFromJson(x)]);
  }

  /// Génère la semaine [w]. Avec [sessions] : enregistre l'aperçu (modifié) tel quel.
  Future<String> generate(int w, {List<Session>? sessions}) async {
    await flushPrep();
    final res = await _mutate(
      () =>
          api.post('/weeks/$w/generate', sessions == null ? null : {'sessions': sessions.map(sessionToJson).toList()}),
    );
    return res['message'] as String;
  }

  Future<String> savePointer(String sessionId, PointerDraft d) async {
    final body = <String, dynamic>{
      'missed': d.missed,
      if (d.missed && d.who != null) 'who': d.who!.name,
      if (d.missed) 'motif': d.motif,
      if (d.missed) 'redo': d.redo,
    };
    try {
      final res = await _mutate(() => api.post('/sessions/${Uri.encodeComponent(sessionId)}/pointer', body));
      return res['message'] as String;
    } on ApiException {
      if (!offline) rethrow;
      // Hors ligne : gardé sur le téléphone, envoyé au retour du réseau.
      pendingPointers = [
        ...pendingPointers,
        {'id': sessionId, 'body': body},
      ];
      await _saveQueue();
      _pointLocally(sessionId, body);
      notifyListeners();
      return 'Hors ligne · pointage gardé, envoyé au retour du réseau';
    }
  }

  // ─── Séances : déplacer, annuler ──────────────────────────────

  /// Déplace ou change l'heure d'une séance prévue.
  Future<String> moveSession(String id, Slot to) async {
    final res = await _mutate(() => api.patch('/sessions/${Uri.encodeComponent(id)}', slotToJson(to)));
    return res['message'] as String;
  }

  /// Annule une séance prévue (absence prévenue), avec ou sans rattrapage.
  Future<String> cancelSession(String id, {required bool redo, Who? who, String motif = ''}) async {
    final res = await _mutate(
      () => api.post('/sessions/${Uri.encodeComponent(id)}/cancel', {
        'redo': redo,
        if (who != null) 'who': who.name,
        if (motif.isNotEmpty) 'motif': motif,
      }),
    );
    return res['message'] as String;
  }

  /// La séance a-t-elle commencé ? (« Faite » n'est possible qu'à partir du début.)
  bool hasStarted(Session s) {
    final t = today();
    final now = clock();
    final nowMin = now.hour * 60 + now.minute;
    return s.week < t.week || (s.week == t.week && (s.day < t.day || (s.day == t.day && s.start <= nowMin)));
  }

  // ─── Indisponibilités du répétiteur ───────────────────────────

  Future<void> setTutorUnavailable(List<TimeBlock> blocks) =>
      _mutate(() => api.patch('/settings', {'unavailable': blocksToJson(blocks)}));

  // ─── Agenda ───────────────────────────────────────────────────

  /// Active (ou renouvelle) le flux agenda : l'ancien lien cesse de marcher.
  Future<void> enableCalendar() => _mutate(() => api.post('/settings/calendar'));

  /// Lien https du flux (Google Agenda : « À partir de l'URL »).
  String? get calendarUrl => calendarToken == null ? null : '${api.baseUrl}/calendar/$calendarToken.ics';

  /// Lien webcal:// (Apple Calendrier : abonnement direct).
  String? get calendarWebcal => calendarUrl?.replaceFirst(RegExp(r'^https?://'), 'webcal://');

  // ─── Argent ───────────────────────────────────────────────────

  Future<void> addPayment(String studentId, {required int amount, required String date, String note = ''}) => _mutate(
    () => api.post('/students/${Uri.encodeComponent(studentId)}/payments', {
      'amount': amount,
      'date': date,
      if (note.trim().isNotEmpty) 'note': note.trim(),
    }),
  );

  Future<void> removePayment(String studentId, String paymentId) => _mutate(
    () => api.delete('/students/${Uri.encodeComponent(studentId)}/payments/${Uri.encodeComponent(paymentId)}'),
  );

  /// Séances faites (ou rattrapées) de l'élève [id] pendant le mois [month] (1–12) de [year].
  List<Session> doneIn(String id, int year, int month) => [
    for (final s in sessions)
      if (s.svc == id &&
          (s.status == SessionStatus.faite || s.status == SessionStatus.rattrapee) &&
          dateOf(s.week, s.day).year == year &&
          dateOf(s.week, s.day).month == month)
        s,
  ];

  /// Paiements de l'élève [id] pendant le mois [month] de [year].
  List<Payment> paymentsIn(String id, int year, int month) =>
      payments.where((p) => p.serviceId == id && p.paidOn.startsWith(_monthKey(year, month))).toList();

  static String _monthKey(int y, int m) => '$y-${m.toString().padLeft(2, '0')}';

  /// Bilan du mois : dû (selon le tarif), payé, reste ; et solde total jusqu'à ce mois.
  ({int done, int due, int paid, int left, int balance}) financeOf(String id, int year, int month) {
    final S = svc(id);
    int dueIn(int y, int m) => S.rate == null
        ? 0
        : S.billing == 'mois'
        ? S.rate!
        : doneIn(id, y, m).length * S.rate!;
    final until = _monthKey(year, month);
    final mine = payments.where((p) => p.serviceId == id).toList();
    // Du premier mois avec une séance faite ou un paiement jusqu'au mois affiché.
    final months = <String>{
      for (final s in sessions.where(
        (s) => s.svc == id && (s.status == SessionStatus.faite || s.status == SessionStatus.rattrapee),
      ))
        _monthKey(dateOf(s.week, s.day).year, dateOf(s.week, s.day).month),
      for (final p in mine) p.paidOn.substring(0, 7),
      until,
    }.where((k) => k.compareTo(until) <= 0).toList()..sort();
    var totalDue = 0;
    var y = int.parse(months.first.substring(0, 4)), m = int.parse(months.first.substring(5));
    while (_monthKey(y, m).compareTo(until) <= 0) {
      totalDue += dueIn(y, m);
      if (++m > 12) {
        m = 1;
        y++;
      }
    }
    final totalPaid = mine.where((p) => p.paidOn.substring(0, 7).compareTo(until) <= 0).fold(0, (a, p) => a + p.amount);
    final due = dueIn(year, month);
    final paid = paymentsIn(id, year, month).fold(0, (a, p) => a + p.amount);
    return (
      done: doneIn(id, year, month).length,
      due: due,
      paid: paid,
      left: due - paid,
      balance: totalDue - totalPaid,
    );
  }

  /// Récap du mois à envoyer au parent.
  String financeMessage(String id, int year, int month) {
    final S = svc(id);
    final f = financeOf(id, year, month);
    final detail = S.billing == 'mois'
        ? 'Forfait du mois : ${money(f.due)}'
        : '${f.done} séance${f.done > 1 ? 's' : ''} faite${f.done > 1 ? 's' : ''}${S.rate != null ? ' × ${money(S.rate!)} = ${money(f.due)}' : ''}';
    return 'Bonjour,\nRécapitulatif de ${S.first} pour ${monthNames[month - 1]} $year :\n'
        '– $detail\n'
        '– Payé : ${money(f.paid)}\n'
        '– Reste à payer : ${money(f.balance > 0 ? f.balance : 0)}\n'
        'Merci.';
  }

  Future<String> addStudent(StudentForm f) async {
    final res = await _mutate(() => api.post('/students', f.toJson()));
    return res['id'] as String;
  }

  /// Modifie la fiche de l'élève [id] (pris en compte aux prochaines générations).
  Future<void> updateStudent(String id, StudentForm f) =>
      _mutate(() => api.patch('/students/${Uri.encodeComponent(id)}', f.toJson()));

  Future<String> cancelRattrapage(RattItem it) async {
    final res = await _mutate(() => api.post('/rattrapages/${Uri.encodeComponent(it.key)}/cancel'));
    return res['message'] as String;
  }

  Future<void> deleteStudent(String id) => _mutate(() => api.delete('/students/${Uri.encodeComponent(id)}'));

  // ─── Succès Group : sites et classes ──────────────────────────

  /// Sites Succès Group, dans l'ordre d'affichage.
  List<Service> get sites => services.values.where((s) => !s.isEleve).toList();

  List<SchoolClass> classesOf(String siteId) => classes.values.where((c) => c.siteId == siteId).toList();

  Future<void> addSite(String name) => _mutate(() => api.post('/sites', {'name': name}));

  Future<void> renameSite(String id, String name) =>
      _mutate(() => api.patch('/sites/${Uri.encodeComponent(id)}', {'name': name}));

  /// Supprime (archive) un site et ses classes : l'historique est conservé côté serveur.
  Future<void> deleteSite(String id) => _mutate(() => api.delete('/sites/${Uri.encodeComponent(id)}'));

  Future<void> addClass(String siteId, String name) =>
      _mutate(() => api.post('/classes', {'name': name, 'siteId': siteId}));

  Future<void> renameClass(String id, String name) =>
      _mutate(() => api.patch('/classes/${Uri.encodeComponent(id)}', {'name': name}));

  /// Supprime (archive) une classe : l'historique est conservé côté serveur.
  Future<void> deleteClass(String id) => _mutate(() => api.delete('/classes/${Uri.encodeComponent(id)}'));

  @override
  void dispose() {
    _retry?.cancel();
    for (final t in _prepTimers.values) {
      t.cancel();
    }
    api.close();
    super.dispose();
  }

  String programmeOf(String id, int w, [List<Session>? ss]) {
    final S = svc(id);
    final mine = week(w, ss).where((s) => s.svc == id && s.status != SessionStatus.manquee).toList()
      ..sort((a, b) => a.day != b.day ? a.day - b.day : a.start - b.start);
    final lines = [
      for (final s in mine)
        '– ${dayLong(w, s.day)} : ${fmt(s.start)} – ${fmt(s.end)}${s.isRattrapage ? ' (rattrapage)' : ''}',
    ];
    return 'Bonjour,\nVoici le programme de ${S.first} pour la semaine ${weekSpan(w)} :\n'
        '${lines.isEmpty ? 'Pas de séance prévue cette semaine.' : lines.join('\n')}\n'
        'Merci de me prévenir en cas d’empêchement. Bonne semaine.';
  }

  List<Session> sortedWeek(int w, [List<Session>? ss]) =>
      week(w, ss)..sort((a, b) => a.day != b.day ? a.day - b.day : a.start - b.start);

  String recapOf(int w, [List<Session>? preview]) {
    final ss = sortedWeek(w, preview);
    final out = ['Planning ${weekSpan(w)}'];
    for (var d = 0; d < 7; d++) {
      final day = ss.where((s) => s.day == d).toList();
      if (day.isEmpty) continue;
      out.add('\n${dayLong(w, d)}');
      for (final s in day) {
        out.add(
          '– ${range(s.start, s.end)} : ${titleOf(s)}${s.cls != null ? ' · ${svc(s.svc).name}' : ''}${s.isRattrapage ? ' (rattrapage)' : ''}',
        );
      }
    }
    return out.join('\n');
  }

  String collectiveOf(int w, [List<Session>? preview]) {
    final ss = sortedWeek(w, preview).where((s) => s.cls != null).toList();
    final out = ['Succès Group · ${weekSpan(w)}'];
    for (final site in services.values.where((s) => !s.isEleve)) {
      final mine = ss.where((s) => s.svc == site.id).toList();
      if (mine.isEmpty) continue;
      out.add('\n${site.name}');
      for (final s in mine) {
        out.add(
          '– ${dayLong(w, s.day)} · ${range(s.start, s.end)} · ${titleOf(s)}${s.isRattrapage ? ' (rattrapage)' : ''}',
        );
      }
    }
    if (out.length == 1) out.add('Aucune séance Succès Group cette semaine.');
    return out.join('\n');
  }

  String ruleOf(Service S) {
    final ex = S.exDays.where((d) => !(S.noWeekend && d >= 5)).toList();
    return '${plural(S.perWeek, 'séance')} de 2 h par semaine'
        '${S.noWeekend ? ' · jamais le week-end' : ''}'
        '${ex.isNotEmpty ? ' · jamais le ${ex.map((d) => dayNamesLower[d]).join(', ')}' : ''}'
        '${S.notBefore != null ? ' · pas avant ${fmt(S.notBefore!)}' : ''}'
        '${S.notAfter != null ? ' · fini avant ${fmt(S.notAfter!)}' : ''}'
        '${S.fixed.isNotEmpty ? ' · fixe le ${S.fixed.map((f) => '${dayNamesLower[f.day]} ${fmt(f.start)}').join(', ')}' : ''}'
        '${S.unavailable.isNotEmpty ? ' · indisponible le ${S.unavailable.map((b) => '${dayNamesLower[b.day]} ${b.label}').join(', ')}' : ''}';
  }
}
