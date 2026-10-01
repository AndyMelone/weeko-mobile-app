const dayNamesShort = ['Lun.', 'Mar.', 'Mer.', 'Jeu.', 'Ven.', 'Sam.', 'Dim.'];
const dayNamesLong = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
const dayNamesLower = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
const monthNames = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];
const monthShort = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];

/// Horloge de l'app. `TODAY` (« 2026-10-06 ») dans `.env.json` fixe la date ; les tests la remplacent.
DateTime Function() clock = () {
  const forced = String.fromEnvironment('TODAY');
  return forced.isEmpty ? DateTime.now() : DateTime.parse(forced);
};

/// Semaine (décalage depuis la semaine 0) et jour (0 = lundi) d'aujourd'hui.
({int week, int day}) today() {
  final n = clock();
  final days = DateTime.utc(n.year, n.month, n.day).difference(DateTime.utc(2026, 10, 5)).inDays;
  final week = (days / 7).floor();
  return (week: week, day: days - week * 7);
}

int get currentWeek => today().week;

DateTime dateOf(int week, int day) => DateTime(2026, 10, 5 + week * 7 + day);

String fmt(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  return '${h}h${m == 0 ? '' : m.toString().padLeft(2, '0')}';
}

String range(int a, int b) => '${fmt(a)}–${fmt(b)}';

String dayShort(int week, int day) {
  final t = dateOf(week, day);
  return '${dayNamesShort[day].toLowerCase()} ${t.day} ${monthShort[t.month - 1]}';
}

String dayLong(int week, int day) {
  final t = dateOf(week, day);
  return '${dayNamesLong[day]} ${t.day} ${monthNames[t.month - 1]}';
}

String weekRange(int week) {
  final a = dateOf(week, 0), b = dateOf(week, 6);
  return a.month == b.month
      ? '${a.day} – ${b.day} ${monthNames[b.month - 1]}'
      : '${a.day} ${monthShort[a.month - 1]} – ${b.day} ${monthShort[b.month - 1]}';
}

String weekSpan(int week) {
  final a = dateOf(week, 0), b = dateOf(week, 6);
  return a.month == b.month
      ? 'du ${a.day} au ${b.day} ${monthNames[b.month - 1]}'
      : 'du ${a.day} ${monthShort[a.month - 1]} au ${b.day} ${monthShort[b.month - 1]}';
}

int weekNum(int week) {
  final d = dateOf(week, 0);
  final jan1 = DateTime.utc(2026, 1, 1);
  final days = DateTime.utc(d.year, d.month, d.day).difference(jan1).inDays;
  return ((days + jan1.weekday % 7 + 1) / 7).ceil();
}

int? parseTime(String? v) {
  if (v == null || v.isEmpty) return null;
  final parts = v.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

String toHhMm(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

String plural(int n, String word) => '$n $word${n > 1 ? 's' : ''}';

String capitalized(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// 25000 → « 25 000 F »
String money(int amount) {
  final digits = amount.abs().toString();
  final groups = <String>[];
  for (var i = digits.length; i > 0; i -= 3) {
    groups.insert(0, digits.substring(i - 3 < 0 ? 0 : i - 3, i));
  }
  return '${amount < 0 ? '-' : ''}${groups.join('\u202f')} F';
}
