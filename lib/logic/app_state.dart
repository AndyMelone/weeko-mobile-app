import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

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
  String name = '';
  String phone = '';
  int count = 2;
  List<int> exDays = [];
  String notBefore = '';
  String notAfter = '';

  List<({int day, String time})> fixed = [];
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
  Future<void> load() async {
    try {
      _apply(await api.get('/state') as Json);
      status = LoadStatus.ready;
      error = null;
    } on ApiException catch (e) {
      if (status != LoadStatus.ready) status = LoadStatus.error;
      error = e.message;
      if (status == LoadStatus.ready) rethrow;
    }
    notifyListeners();
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

  List<Session> get decided => week(0).where((s) => s.base && s.fixed).toList();

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

  int unplaced(String c, int w, [List<Session>? ss]) {
    if (!generated.contains(w) || prepOf(w).times.containsKey(c)) return 0;
    final placed = week(w, ss).where((s) => s.cls == c && !s.isRattrapage).length;
    return max(0, (prepOf(w).counts[c] ?? 0) - placed);
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
          week: 0,
          placedSession: ps,
          title: u.cls != null ? '${classes[u.cls]!.name} · ${svc(u.svc).name}' : svc(u.svc).name,
          detail: 'Manquée ${u.from} · ${whoLabel(u)}${u.motif.isNotEmpty ? ' · ${u.motif}' : ''}',
          placed: ps == null ? null : '${dayShort(ps.week, ps.day)} · ${range(ps.start, ps.end)}',
        ),
      );
    }
    for (final w in (generated.toList()..sort())) {
      for (final c in classes.values) {
        final n = unplaced(c.id, w);
        for (var i = 0; i < n; i++) {
          out.add(
            RattItem(
              key: 'u-$w${c.id}$i',
              svc: c.siteId,
              cls: c.id,
              week: w,
              title: '${c.name} · ${svc(c.siteId).name}',
              detail: 'Séance demandée semaine du ${weekRange(w)}, aucun créneau trouvé par le planning.',
            ),
          );
        }
      }
    }
    return [...out.where((i) => i.placed == null), ...out.where((i) => i.placed != null)];
  }

  int get todoCount => items().where((i) => i.placed == null).length;

  Slot? resolveChoice(RattItem it, SlotChoice? choice) => switch (choice) {
    ProposalChoice(:final index) => proposals(it).elementAtOrNull(index),
    DayChoice(:final day) => slots(it.svc, onlyDay: day, w: it.week).firstOrNull,
    null => null,
  };

  Future<String?> place(RattItem it, SlotChoice? choice) async {
    final body = switch (choice) {
      ProposalChoice(:final index) => {'proposal': index},
      DayChoice(:final day) => {'day': day},
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

  Future<String> generate(int w) async {
    await flushPrep();
    final res = await _mutate(() => api.post('/weeks/$w/generate'));
    return res['message'] as String;
  }

  Future<String> savePointer(String sessionId, PointerDraft d) async {
    final res = await _mutate(
      () => api.post('/sessions/${Uri.encodeComponent(sessionId)}/pointer', {
        'missed': d.missed,
        if (d.missed && d.who != null) 'who': d.who!.name,
        if (d.missed) 'motif': d.motif,
        if (d.missed) 'redo': d.redo,
      }),
    );
    return res['message'] as String;
  }

  Future<String> addStudent(StudentForm f) async {
    final res = await _mutate(
      () => api.post('/students', {
        'name': f.name.trim(),
        'phone': f.phone,
        'count': f.count,
        'exDays': f.exDays,
        'notBefore': f.notBefore,
        'notAfter': f.notAfter,
        'fixed': [
          for (final x in f.fixed) {'day': x.day, 'time': x.time},
        ],
      }),
    );
    return res['id'] as String;
  }

  Future<String> cancelRattrapage(RattItem it) async {
    final res = await _mutate(() => api.post('/rattrapages/${Uri.encodeComponent(it.key)}/cancel'));
    return res['message'] as String;
  }

  Future<void> deleteStudent(String id) => _mutate(() => api.delete('/students/${Uri.encodeComponent(id)}'));

  @override
  void dispose() {
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
