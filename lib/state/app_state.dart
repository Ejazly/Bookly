import 'package:flutter/widgets.dart';

import '../data/sample_data.dart';
import '../models/models.dart';

/// Error que se lanza cuando un horario ya no se puede reservar.
class BookingException implements Exception {
  BookingException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Estado global de la app: negocios, citas y la lógica de la agenda.
///
/// Es un [ChangeNotifier]: cada vez que algo cambia llamamos a
/// `notifyListeners()` y las pantallas que lo usan se vuelven a dibujar.
class AppState extends ChangeNotifier {
  AppState({
    DateTime Function()? clock,
    bool seed = true,
    List<Business>? catalog,
  })  : _clock = clock ?? DateTime.now,
        businesses = catalog ?? sampleBusinesses {
    if (seed) _seedBookings();
  }

  /// Cada cuántos minutos se ofrece un horario (10:00, 11:00, 12:00...).
  static const int slotStepMinutes = 60;

  final DateTime Function() _clock;
  final List<Business> businesses;
  final List<Appointment> _appointments = [];
  int _nextId = 1;

  String userName = 'Ana';

  // Pestaña seleccionada en la barra inferior (0 Inicio, 1 Videos, 2 Mis citas, 3 Perfil).
  int _tab = 0;
  int get tab => _tab;
  set tab(int value) {
    _tab = value;
    notifyListeners();
  }

  /// Hora actual. En las pruebas se reemplaza por una hora fija.
  DateTime get now => _clock();

  // ---------------------------------------------------------------------------
  // Consultas
  // ---------------------------------------------------------------------------

  List<Appointment> get myAppointments =>
      _appointments.where((a) => a.fromCurrentUser).toList();

  /// Citas de la usuaria que todavía no pasan y no están canceladas.
  List<Appointment> get upcoming {
    final list = myAppointments
        .where((a) => !a.isCancelled && a.end.isAfter(now))
        .toList();
    list.sort((a, b) => a.start.compareTo(b.start));
    return list;
  }

  /// Citas canceladas o que ya pasaron.
  List<Appointment> get history {
    final list = myAppointments
        .where((a) => a.isCancelled || !a.end.isAfter(now))
        .toList();
    list.sort((a, b) => b.start.compareTo(a.start));
    return list;
  }

  /// Todas las citas activas de un negocio en un día (para el panel del negocio).
  List<Appointment> agendaFor(Business business, DateTime day) {
    final list = _appointments
        .where((a) =>
            !a.isCancelled &&
            a.business.id == business.id &&
            a.start.year == day.year &&
            a.start.month == day.month &&
            a.start.day == day.day)
        .toList();
    list.sort((a, b) => a.start.compareTo(b.start));
    return list;
  }

  // ---------------------------------------------------------------------------
  // Lógica de horarios
  // ---------------------------------------------------------------------------

  /// Genera los horarios posibles de un día, respetando la hora de apertura,
  /// la de cierre y la duración del servicio.
  List<DateTime> slotsFor(Business business, Service service, DateTime day) {
    if (!business.isOpenOn(day)) return [];
    final result = <DateTime>[];
    final close = DateTime(day.year, day.month, day.day, business.closeHour);
    var minutes = 0;
    while (true) {
      final start = DateTime(
          day.year, day.month, day.day, business.openHour, minutes);
      final end = start.add(Duration(minutes: service.minutes));
      if (end.isAfter(close)) break;
      result.add(start);
      minutes += slotStepMinutes;
    }
    return result;
  }

  /// ¿El profesional está libre de [start] a [start + minutes]?
  /// Dos citas chocan si una empieza antes de que termine la otra.
  bool isProfessionalFree(
    Business business,
    Professional pro,
    DateTime start,
    int minutes, {
    String? ignoreId,
  }) {
    final end = start.add(Duration(minutes: minutes));
    for (final a in _appointments) {
      if (a.id == ignoreId || a.isCancelled) continue;
      if (a.business.id != business.id || a.professional.id != pro.id) continue;
      final overlaps = a.start.isBefore(end) && start.isBefore(a.end);
      if (overlaps) return false;
    }
    return true;
  }

  /// Busca quién puede atender en ese horario.
  /// Si [preferred] es null ("Cualquiera"), regresa el primer profesional libre.
  /// Regresa null si el horario ya pasó o nadie está libre.
  Professional? findProfessional(
    Business business,
    Service service,
    DateTime start, {
    Professional? preferred,
    String? ignoreId,
  }) {
    if (!start.isAfter(now)) return null;
    final candidates =
        preferred != null ? [preferred] : business.professionals;
    for (final p in candidates) {
      if (isProfessionalFree(business, p, start, service.minutes,
          ignoreId: ignoreId)) {
        return p;
      }
    }
    return null;
  }

  bool isSlotAvailable(
    Business business,
    Service service,
    DateTime start, {
    Professional? preferred,
    String? ignoreId,
  }) =>
      findProfessional(business, service, start,
          preferred: preferred, ignoreId: ignoreId) !=
      null;

  // ---------------------------------------------------------------------------
  // Acciones
  // ---------------------------------------------------------------------------

  /// Crea la cita después de que el anticipo se pagó.
  Appointment book({
    required Business business,
    required Service service,
    required DateTime start,
    Professional? preferred,
    String note = '',
  }) {
    final pro =
        findProfessional(business, service, start, preferred: preferred);
    if (pro == null) {
      throw BookingException(
          'Ese horario ya no está disponible. Por favor elige otro.');
    }
    final appointment = Appointment(
      id: 'c${_nextId++}',
      business: business,
      service: service,
      professional: pro,
      start: start,
      clientName: userName,
      note: note,
      depositPaid: service.deposit,
      fromCurrentUser: true,
    );
    _appointments.add(appointment);
    notifyListeners();
    return appointment;
  }

  /// Política: si faltan 24 horas o más, el anticipo se reembolsa.
  bool isRefundable(Appointment a) =>
      a.start.difference(now) >= const Duration(hours: 24);

  void cancel(Appointment a) {
    a.status = AppointmentStatus.cancelada;
    notifyListeners();
  }

  /// Cambia la fecha/hora de una cita. El anticipo pagado se conserva.
  void reschedule(Appointment a, DateTime newStart, {Professional? preferred}) {
    final pro = findProfessional(a.business, a.service, newStart,
        preferred: preferred, ignoreId: a.id);
    if (pro == null) {
      throw BookingException(
          'Ese horario ya no está disponible. Por favor elige otro.');
    }
    a.start = newStart;
    a.professional = pro;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Datos de ejemplo
  // ---------------------------------------------------------------------------

  /// Crea citas de otros clientes para que la agenda tenga horarios ocupados.
  void _seedBookings() {
    const names = [
      'Mario R.', 'José P.', 'Laura G.', 'Diana S.', 'Carlos M.', 'Fernanda T.',
    ];
    final today = DateTime(now.year, now.month, now.day);
    var n = 0;
    for (var bi = 0; bi < businesses.length; bi++) {
      final b = businesses[bi];
      final hours = b.closeHour - b.openHour - 1;
      for (var d = 0; d < 10; d++) {
        final day = DateTime(today.year, today.month, today.day + d);
        if (!b.isOpenOn(day)) continue;
        for (var pi = 0; pi < b.professionals.length; pi++) {
          final p = b.professionals[pi];
          for (var k = 0; k < 3; k++) {
            final hour = b.openHour + ((d * 3 + pi * 2 + k * 3 + bi) % hours);
            final s = b.services[(d + k + pi) % b.services.length];
            final start = DateTime(day.year, day.month, day.day, hour);
            final close = DateTime(day.year, day.month, day.day, b.closeHour);
            if (start.add(Duration(minutes: s.minutes)).isAfter(close)) continue;
            if (!isProfessionalFree(b, p, start, s.minutes)) continue;
            _appointments.add(Appointment(
              id: 's${n++}',
              business: b,
              service: s,
              professional: p,
              start: start,
              clientName: names[n % names.length],
              depositPaid: s.deposit,
            ));
          }
        }
      }
    }
  }
}

/// Hace que [AppState] esté disponible para todas las pantallas.
///
/// - `AppScope.of(context)` se usa dentro de `build`: la pantalla se
///   redibuja sola cuando el estado cambia.
/// - `AppScope.read(context)` se usa dentro de botones o funciones.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
