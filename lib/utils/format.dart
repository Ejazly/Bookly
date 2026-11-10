// Funciones pequeñas para mostrar fechas, horas y dinero en español
// sin necesidad de instalar paquetes extra.

const List<String> _days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const List<String> _daysLong = [
  'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo',
];
const List<String> _months = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];
const List<String> _monthsShort = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

String two(int n) => n.toString().padLeft(2, '0');

/// 16:00
String hhmm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

/// Mar
String dayName(DateTime d) => _days[d.weekday - 1];

/// Nombre corto de un día de la semana (DateTime.monday = 1 ... sunday = 7).
String weekdayShort(int weekday) => _days[weekday - 1];

/// 1 = "lunes" ... 7 = "domingo".
String weekdayLong(int weekday) => _daysLong[weekday - 1];

/// Mar 27 oct
String shortDate(DateTime d) =>
    '${dayName(d)} ${d.day} ${_monthsShort[d.month - 1]}';

/// martes 27 de octubre
String longDate(DateTime d) =>
    '${_daysLong[d.weekday - 1]} ${d.day} de ${_months[d.month - 1]}';

/// Octubre 2026
String monthYear(DateTime d) {
  final m = _months[d.month - 1];
  return '${m[0].toUpperCase()}${m.substring(1)} ${d.year}';
}

/// $230 o $57.50
String money(double v) => v == v.roundToDouble()
    ? '\$${v.toStringAsFixed(0)}'
    : '\$${v.toStringAsFixed(2)}';

/// Siempre con centavos: $57.50
String money2(double v) => '\$${v.toStringAsFixed(2)}';

/// 45 min, 1 h, 1 h 30 min
String durationText(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

/// "hace 5 min", "hace 2 h", "hace 3 días" o la fecha.
String timeAgo(DateTime? d, DateTime now) {
  if (d == null) return 'Ahora';
  final diff = now.difference(d);
  if (diff.inMinutes < 1) return 'Ahora';
  if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
  if (diff.inDays < 7) {
    return diff.inDays == 1 ? 'Hace 1 día' : 'Hace ${diff.inDays} días';
  }
  return shortDate(d);
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Lista de días a partir de hoy: hoy, mañana, ...
List<DateTime> nextDays(DateTime now, int count) {
  final today = dateOnly(now);
  return List.generate(
    count,
    (i) => DateTime(today.year, today.month, today.day + i),
  );
}
