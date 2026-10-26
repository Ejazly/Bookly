// Funciones pequeñas para mostrar fechas, horas y dinero en español
// sin necesidad de instalar paquetes extra.

const List<String> _days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
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

/// Mar 27 oct
String shortDate(DateTime d) =>
    '${dayName(d)} ${d.day} ${_monthsShort[d.month - 1]}';

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

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
