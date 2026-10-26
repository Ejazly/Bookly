// Pruebas funcionales de Bookly.
// Se ejecutan con:  flutter test
//
// Usamos una hora fija (lunes 26 de octubre de 2026, 8:00 a. m.) para que
// los resultados siempre sean los mismos sin importar cuándo se corran.

import 'package:flutter_test/flutter_test.dart';

import 'package:bookly/main.dart';
import 'package:bookly/models/models.dart';
import 'package:bookly/state/app_state.dart';

void main() {
  final fixedNow = DateTime(2026, 10, 26, 8);

  AppState newState({DateTime? now}) =>
      AppState(clock: () => now ?? fixedNow, seed: false);

  group('PF-08 Anticipo del 25 %', () {
    test('un servicio de \$230 genera un anticipo de \$57.50', () {
      expect(depositFor(230), 57.5);
      expect(230 - depositFor(230), 172.5);
    });

    test('el anticipo se redondea a centavos', () {
      expect(depositFor(155), 38.75);
      expect(depositFor(99.99), 25.0);
    });
  });

  group('Horarios disponibles', () {
    test('se generan dentro del horario del negocio', () {
      final s = newState();
      final barberia = s.businesses[0]; // abre 10:00 a 20:00
      final corteBarba = barberia.services[1]; // 60 min
      final slots = s.slotsFor(barberia, corteBarba, DateTime(2026, 10, 26));
      expect(slots.first, DateTime(2026, 10, 26, 10));
      expect(slots.last, DateTime(2026, 10, 26, 19));
      expect(slots.length, 10);
    });

    test('no hay horarios el día que cierra el negocio (domingo)', () {
      final s = newState();
      final barberia = s.businesses[0];
      final slots = s.slotsFor(
          barberia, barberia.services[0], DateTime(2026, 11, 1));
      expect(slots, isEmpty);
    });

    test('no se pueden reservar horarios que ya pasaron', () {
      final s = newState(now: DateTime(2026, 10, 26, 12));
      final barberia = s.businesses[0];
      final corte = barberia.services[0];
      expect(s.isSlotAvailable(barberia, corte, DateTime(2026, 10, 26, 11)),
          isFalse);
      expect(s.isSlotAvailable(barberia, corte, DateTime(2026, 10, 26, 13)),
          isTrue);
    });
  });

  group('PF-07 Reservas y horarios ocupados', () {
    test('un horario se ocupa cuando todos los profesionales están ocupados',
        () {
      final s = newState();
      final barberia = s.businesses[0]; // Luis y Andrés
      final corteBarba = barberia.services[1];
      final t = DateTime(2026, 10, 27, 16);

      expect(s.isSlotAvailable(barberia, corteBarba, t), isTrue);

      final primera = s.book(business: barberia, service: corteBarba, start: t);
      expect(primera.professional.name, 'Luis');
      // Luis ya no está libre, pero Andrés sí.
      expect(
          s.isSlotAvailable(barberia, corteBarba, t,
              preferred: primera.professional),
          isFalse);
      expect(s.isSlotAvailable(barberia, corteBarba, t), isTrue);

      final segunda = s.book(business: barberia, service: corteBarba, start: t);
      expect(segunda.professional.name, 'Andrés');
      expect(s.isSlotAvailable(barberia, corteBarba, t), isFalse);

      // Intentar reservar el mismo horario otra vez debe fallar.
      expect(
        () => s.book(business: barberia, service: corteBarba, start: t),
        throwsA(isA<BookingException>()),
      );
    });

    test('un servicio largo bloquea los horarios que se empalman', () {
      final s = newState();
      final estetica = s.businesses[1];
      final tinte = estetica.services[1]; // 120 min
      final corte = estetica.services[0]; // 60 min
      final mariana = estetica.professionals[0];

      s.book(
        business: estetica,
        service: tinte,
        start: DateTime(2026, 10, 27, 10),
        preferred: mariana,
      );
      // El tinte dura de 10:00 a 12:00.
      expect(
          s.isSlotAvailable(estetica, corte, DateTime(2026, 10, 27, 11),
              preferred: mariana),
          isFalse);
      expect(
          s.isSlotAvailable(estetica, corte, DateTime(2026, 10, 27, 12),
              preferred: mariana),
          isTrue);
    });

    test('PF-10 la cita pagada aparece en Próximas', () {
      final s = newState();
      final barberia = s.businesses[0];
      final cita = s.book(
        business: barberia,
        service: barberia.services[1],
        start: DateTime(2026, 10, 27, 16),
        note: 'Degradado bajo',
      );
      expect(s.upcoming, [cita]);
      expect(cita.depositPaid, 57.5);
      expect(cita.remaining, 172.5);
      expect(cita.status, AppointmentStatus.confirmada);
    });
  });

  group('Cancelar y reprogramar', () {
    test('cancelar con más de 24 h libera el horario y es reembolsable', () {
      final s = newState();
      final barberia = s.businesses[0];
      final servicio = barberia.services[1];
      final t = DateTime(2026, 10, 27, 16);
      final luis = barberia.professionals[0];

      final cita =
          s.book(business: barberia, service: servicio, start: t, preferred: luis);
      expect(s.isRefundable(cita), isTrue);

      s.cancel(cita);
      expect(s.upcoming, isEmpty);
      expect(s.history.first.status, AppointmentStatus.cancelada);
      expect(s.isSlotAvailable(barberia, servicio, t, preferred: luis), isTrue);
    });

    test('con menos de 24 h el anticipo no es reembolsable', () {
      final s = newState();
      final barberia = s.businesses[0];
      final cita = s.book(
        business: barberia,
        service: barberia.services[0],
        start: DateTime(2026, 10, 26, 10),
      );
      expect(s.isRefundable(cita), isFalse);
    });

    test('reprogramar mueve la cita y libera el horario anterior', () {
      final s = newState();
      final barberia = s.businesses[0];
      final servicio = barberia.services[1];
      final luis = barberia.professionals[0];
      final antes = DateTime(2026, 10, 27, 16);
      final despues = DateTime(2026, 10, 28, 12);

      final cita = s.book(
          business: barberia, service: servicio, start: antes, preferred: luis);
      s.reschedule(cita, despues, preferred: luis);

      expect(cita.start, despues);
      expect(s.isSlotAvailable(barberia, servicio, antes, preferred: luis),
          isTrue);
      expect(s.isSlotAvailable(barberia, servicio, despues, preferred: luis),
          isFalse);
    });
  });

  testWidgets('la app abre en la pantalla de inicio de sesión', (tester) async {
    await tester.pumpWidget(BooklyApp(state: AppState(clock: () => fixedNow)));
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Bookly'), findsOneWidget);
  });
}
