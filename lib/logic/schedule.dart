// Lógica de la agenda. Son funciones "puras": no usan Firebase ni pantallas,
// solo reciben datos y regresan un resultado. Por eso se pueden probar con
// `flutter test` sin internet.

import '../models/models.dart';

/// Cada cuántos minutos se ofrece un horario (10:00, 11:00, 12:00...).
const int slotStepMinutes = 60;

/// Error que se lanza cuando un horario ya no se puede reservar.
class BookingException implements Exception {
  BookingException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Horarios posibles de un día: desde la apertura, cada [slotStepMinutes],
/// siempre que el servicio termine antes o justo a la hora de cierre.
List<DateTime> slotsFor(Business business, int minutes, DateTime day) {
  if (!business.isOpenOn(day)) return const [];
  final close = DateTime(day.year, day.month, day.day, business.closeHour);
  final result = <DateTime>[];
  var start = DateTime(day.year, day.month, day.day, business.openHour);
  while (!start.add(Duration(minutes: minutes)).isAfter(close)) {
    result.add(start);
    start = start.add(const Duration(minutes: slotStepMinutes));
  }
  return result;
}

/// Horarios de UNA persona en un día: solo dentro de su turno y del horario
/// del negocio, y nunca en sus días de descanso.
List<DateTime> slotsForMember(
  Business business,
  StaffMember member,
  int minutes,
  DateTime day,
) {
  if (!member.worksOn(day)) return const [];
  return slotsFor(business, minutes, day)
      .where((t) => memberWorksAt(member, t, minutes))
      .toList();
}

/// ¿La cita de [start] a [start] + [minutes] cae dentro del turno de [member]?
bool memberWorksAt(StaffMember member, DateTime start, int minutes) {
  if (!member.worksOn(start)) return false;
  final shiftStart = DateTime(start.year, start.month, start.day, member.startHour);
  final shiftEnd = DateTime(start.year, start.month, start.day, member.endHour);
  final end = start.add(Duration(minutes: minutes));
  return !start.isBefore(shiftStart) && !end.isAfter(shiftEnd);
}

/// Dos citas chocan si una empieza antes de que termine la otra.
bool overlaps(DateTime aStart, DateTime aEnd, DateTime bStart, DateTime bEnd) =>
    aStart.isBefore(bEnd) && bStart.isBefore(aEnd);

/// ¿[professional] está libre de [start] a [start] + [minutes]?
/// Se ignoran las citas canceladas, los apartados sin pagar que ya vencieron
/// y la cita [ignoreId] (al reprogramar).
bool isProfessionalFree({
  required String professional,
  required DateTime start,
  required int minutes,
  required Iterable<Appointment> existing,
  String? ignoreId,
  DateTime? now,
}) {
  final end = start.add(Duration(minutes: minutes));
  final reference = now ?? DateTime.now();
  for (final a in existing) {
    if (a.id == ignoreId || !a.blocksSlot(reference)) continue;
    if (a.professional != professional) continue;
    if (overlaps(a.start, a.end, start, end)) return false;
  }
  return true;
}

/// Busca quién puede atender en ese horario.
/// Si [preferred] es null ("Cualquiera") regresa el primer profesional libre.
/// Regresa null si el horario ya pasó o nadie está libre.
String? findProfessional({
  required Business business,
  required DateTime start,
  required int minutes,
  required Iterable<Appointment> existing,
  required DateTime now,
  String? preferred,
  String? ignoreId,
}) {
  if (!start.isAfter(now)) return null;
  final candidates = preferred != null ? [preferred] : business.staff;
  for (final p in candidates) {
    // Debe estar en su turno (si es alguien del personal registrado).
    final member = business.memberNamed(p);
    if (member != null && !memberWorksAt(member, start, minutes)) continue;
    final free = isProfessionalFree(
      professional: p,
      start: start,
      minutes: minutes,
      existing: existing,
      ignoreId: ignoreId,
      now: now,
    );
    if (free) return p;
  }
  return null;
}

/// Política de cancelación: con 24 horas o más de anticipación se reembolsa.
bool isRefundable(Appointment a, DateTime now) =>
    a.start.difference(now) >= const Duration(hours: 24);

/// Separa las citas de un cliente en próximas e historial.
({List<Appointment> upcoming, List<Appointment> history}) splitAppointments(
  Iterable<Appointment> all,
  DateTime now,
) {
  final upcoming = <Appointment>[];
  final history = <Appointment>[];
  for (final a in all) {
    if (a.blocksSlot(now) && a.end.isAfter(now)) {
      upcoming.add(a);
    } else {
      history.add(a);
    }
  }
  upcoming.sort((a, b) => a.start.compareTo(b.start));
  history.sort((a, b) => b.start.compareTo(a.start));
  return (upcoming: upcoming, history: history);
}
