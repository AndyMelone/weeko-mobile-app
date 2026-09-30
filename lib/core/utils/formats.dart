// Formats de dates et d'heures (français). Les semaines sont des décalages
// par rapport à la semaine de démo (w = 0 : lundi 5 octobre 2026).

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

DateTime dateOf(int week, int day) => DateTime(2026, 10, 5 + week * 7 + day);

/// 930 → « 15h30 », 900 → « 15h ».
String fmt(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  return '${h}h${m == 0 ? '' : m.toString().padLeft(2, '0')}';
}

String range(int a, int b) => '${fmt(a)}–${fmt(b)}';

/// « lun. 5 oct. »
String dayShort(int week, int day) {
  final t = dateOf(week, day);
  return '${dayNamesShort[day].toLowerCase()} ${t.day} ${monthShort[t.month - 1]}';
}

/// « Lundi 5 octobre »
String dayLong(int week, int day) {
  final t = dateOf(week, day);
  return '${dayNamesLong[day]} ${t.day} ${monthNames[t.month - 1]}';
}

/// « 5 – 11 octobre » ou « 26 oct. – 1 nov. »
String weekRange(int week) {
  final a = dateOf(week, 0), b = dateOf(week, 6);
  return a.month == b.month
      ? '${a.day} – ${b.day} ${monthNames[b.month - 1]}'
      : '${a.day} ${monthShort[a.month - 1]} – ${b.day} ${monthShort[b.month - 1]}';
}

/// « du 5 au 11 octobre » ou « du 26 oct. au 1 nov. »
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

/// « 15:30 » → 930 ; vide → null.
int? parseTime(String? v) {
  if (v == null || v.isEmpty) return null;
  final parts = v.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

/// 930 → « 15:30 »
String toHhMm(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

String plural(int n, String word) => '$n $word${n > 1 ? 's' : ''}';
