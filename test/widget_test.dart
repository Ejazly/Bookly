// Pruebas de la lógica de Bookly. Se ejecutan con:  flutter test
//
// Prueban las funciones "puras" (agenda, anticipo, conversión de datos),
// así que no necesitan internet ni Firebase.
// Usamos una hora fija (lunes 26 de octubre de 2026, 8:00 a. m.).

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter_test/flutter_test.dart';

import 'package:bookly/logic/geo.dart';
import 'package:bookly/logic/schedule.dart';
import 'package:bookly/models/models.dart';

void main() {
  final now = DateTime(2026, 10, 26, 8);

  const barberia = Business(
    id: 'b1',
    ownerUid: 'b1',
    ownerEmail: 'dueno@gmail.com',
    name: 'Barbería El Clásico',
    category: BusinessCategory.barberias,
    address: 'Av. Universidad 120',
    phone: '',
    openHour: 10,
    closeHour: 20,
    closedWeekdays: {DateTime.sunday},
    professionals: ['Luis', 'Andrés'],
  );

  const corteBarba = Item(
    id: 's2',
    kind: ItemKind.servicio,
    name: 'Corte + barba',
    price: 230,
    minutes: 60,
  );

  Appointment cita({
    required String id,
    required DateTime start,
    required String professional,
    int minutes = 60,
    AppointmentStatus status = AppointmentStatus.confirmada,
  }) =>
      Appointment(
        id: id,
        businessId: barberia.id,
        businessName: barberia.name,
        ownerEmail: barberia.ownerEmail,
        itemId: 's2',
        serviceName: 'Corte + barba',
        minutes: minutes,
        price: 230,
        depositPaid: 57.5,
        professional: professional,
        start: start,
        clientName: 'Ana',
        clientEmail: 'ana@gmail.com',
        status: status,
      );

  group('Anticipo del 25 %', () {
    test('un servicio de \$230 genera un anticipo de \$57.50', () {
      expect(corteBarba.deposit, 57.5);
      expect(230 - corteBarba.deposit, 172.5);
    });

    test('el anticipo se redondea a centavos', () {
      expect(depositFor(155), 38.75);
      expect(depositFor(99.99), 25.0);
    });
  });

  group('Horarios', () {
    test('se generan de la apertura al cierre según la duración', () {
      final slots = slotsFor(barberia, 60, DateTime(2026, 10, 26));
      expect(slots.first, DateTime(2026, 10, 26, 10));
      expect(slots.last, DateTime(2026, 10, 26, 19));
      expect(slots.length, 10);
    });

    test('un servicio de 2 h no ofrece horarios que terminen después del cierre', () {
      final slots = slotsFor(barberia, 120, DateTime(2026, 10, 26));
      expect(slots.last, DateTime(2026, 10, 26, 18));
    });

    test('no hay horarios el día que cierra el negocio (domingo)', () {
      expect(slotsFor(barberia, 60, DateTime(2026, 11, 1)), isEmpty);
    });

    test('no se pueden reservar horarios que ya pasaron', () {
      final mediodia = DateTime(2026, 10, 26, 12);
      expect(
        findProfessional(
          business: barberia,
          start: DateTime(2026, 10, 26, 11),
          minutes: 60,
          existing: const [],
          now: mediodia,
        ),
        isNull,
      );
    });
  });

  group('Horarios ocupados', () {
    final t = DateTime(2026, 10, 27, 16);

    test('con "Cualquiera" se asigna el primer profesional libre', () {
      final ocupados = [cita(id: 'c1', start: t, professional: 'Luis')];
      expect(
        findProfessional(
            business: barberia, start: t, minutes: 60, existing: ocupados, now: now),
        'Andrés',
      );
    });

    test('si todos están ocupados el horario no está disponible', () {
      final ocupados = [
        cita(id: 'c1', start: t, professional: 'Luis'),
        cita(id: 'c2', start: t, professional: 'Andrés'),
      ];
      expect(
        findProfessional(
            business: barberia, start: t, minutes: 60, existing: ocupados, now: now),
        isNull,
      );
    });

    test('un servicio largo bloquea las horas que se empalman', () {
      final tinte = [
        cita(id: 'c1', start: DateTime(2026, 10, 27, 10), professional: 'Luis', minutes: 120),
      ];
      bool libre(int hour) => isProfessionalFree(
            professional: 'Luis',
            start: DateTime(2026, 10, 27, hour),
            minutes: 60,
            existing: tinte,
          );
      expect(libre(11), isFalse); // 10:00–12:00 ocupado
      expect(libre(12), isTrue);
    });

    test('las citas canceladas liberan el horario', () {
      final canceladas = [
        cita(id: 'c1', start: t, professional: 'Luis', status: AppointmentStatus.cancelada),
      ];
      expect(
        isProfessionalFree(professional: 'Luis', start: t, minutes: 60, existing: canceladas),
        isTrue,
      );
    });

    test('al reprogramar, la cita no choca consigo misma', () {
      final propia = [cita(id: 'c1', start: t, professional: 'Luis')];
      expect(
        isProfessionalFree(
            professional: 'Luis', start: t, minutes: 60, existing: propia, ignoreId: 'c1'),
        isTrue,
      );
    });
  });

  group('Horario de cada persona del personal', () {
    // Evelyn: 10–16, descansa lunes. Sandy: 14–20.
    const conTurnos = Business(
      id: 'b2',
      ownerUid: 'b2',
      ownerEmail: 'yo@gmail.com',
      name: 'Uñas Coral',
      category: BusinessCategory.otro,
      customCategory: 'Pestañas y uñas',
      address: 'Centro',
      phone: '',
      openHour: 10,
      closeHour: 20,
      closedWeekdays: {DateTime.sunday},
      professionals: ['Evelyn', 'Sandy'],
      staffMembers: [
        StaffMember(name: 'Evelyn', startHour: 10, endHour: 16, daysOff: {DateTime.monday}),
        StaffMember(name: 'Sandy', startHour: 14, endHour: 20),
      ],
    );
    final martes = DateTime(2026, 10, 27);

    test('cada persona solo ofrece horarios dentro de su turno', () {
      final evelyn = conTurnos.memberNamed('Evelyn')!;
      final sandy = conTurnos.memberNamed('Sandy')!;
      final e = slotsForMember(conTurnos, evelyn, 60, martes);
      final s = slotsForMember(conTurnos, sandy, 60, martes);
      expect(e.first.hour, 10);
      expect(e.last.hour, 15); // termina a las 16:00
      expect(s.first.hour, 14);
      expect(s.last.hour, 19);
    });

    test('en su día de descanso no tiene horarios', () {
      final lunes = DateTime(2026, 10, 26);
      expect(slotsForMember(conTurnos, conTurnos.memberNamed('Evelyn')!, 60, lunes), isEmpty);
    });

    test('"Cualquiera" asigna a quien esté en turno', () {
      final a = findProfessional(
        business: conTurnos,
        start: DateTime(2026, 10, 27, 18),
        minutes: 60,
        existing: const [],
        now: now,
      );
      expect(a, 'Sandy'); // a las 18:00 Evelyn ya salió
    });

    test('se muestra el tipo de negocio escrito a mano y se guarda el turno', () {
      expect(conTurnos.categoryLabel, 'Pestañas y uñas');
      final leido = Business.fromMap('b2', conTurnos.toMap());
      expect(leido.categoryLabel, 'Pestañas y uñas');
      expect(leido.team.length, 2);
      expect(leido.memberNamed('Evelyn')!.endHour, 16);
      expect(leido.memberNamed('Evelyn')!.daysOff, {DateTime.monday});
    });
  });

  group('Mis citas y cancelación', () {
    test('se separan en próximas e historial', () {
      final citas = [
        cita(id: 'pasada', start: DateTime(2026, 10, 20, 10), professional: 'Luis'),
        cita(id: 'proxima', start: DateTime(2026, 10, 28, 10), professional: 'Luis'),
        cita(
          id: 'cancelada',
          start: DateTime(2026, 10, 29, 10),
          professional: 'Luis',
          status: AppointmentStatus.cancelada,
        ),
      ];
      final r = splitAppointments(citas, now);
      expect(r.upcoming.map((a) => a.id), ['proxima']);
      expect(r.history.map((a) => a.id), containsAll(['pasada', 'cancelada']));
    });

    test('con más de 24 h el anticipo es reembolsable; con menos, no', () {
      expect(isRefundable(cita(id: 'a', start: DateTime(2026, 10, 27, 16), professional: 'Luis'), now), isTrue);
      expect(isRefundable(cita(id: 'b', start: DateTime(2026, 10, 26, 18), professional: 'Luis'), now), isFalse);
    });
  });

  group('Datos de Firestore', () {
    test('una cita se guarda y se lee igual', () {
      final original = cita(id: 'x', start: DateTime(2026, 10, 27, 16), professional: 'Luis');
      final map = original.toMap();
      expect(map['day'], '2026-10-27');
      expect(map['start'], isA<Timestamp>());

      final leida = Appointment.fromMap('x', map);
      expect(leida.start, original.start);
      expect(leida.professional, 'Luis');
      expect(leida.depositPaid, 57.5);
      expect(leida.clientEmail, 'ana@gmail.com');
    });

    test('un producto se guarda y se lee igual', () {
      const shampoo = Item(
        id: 'p1',
        kind: ItemKind.producto,
        name: 'Shampoo',
        price: 190,
        stock: 8,
        description: '400 ml',
      );
      final leido = Item.fromMap('p1', shampoo.toMap());
      expect(leido.isService, isFalse);
      expect(leido.stock, 8);
      expect(leido.price, 190);
      expect(leido.imageBase64, isNull);
    });

    test('un negocio conserva sus días de descanso y su personal', () {
      final leido = Business.fromMap('b1', barberia.toMap());
      expect(leido.closedWeekdays, {DateTime.sunday});
      expect(leido.staff, ['Luis', 'Andrés']);
      expect(leido.category, BusinessCategory.barberias);
    });

    test('el diseño del sitio se guarda aparte de los datos generales', () {
      final decorado = barberia.withSite(
        slogan: 'Cortes con estilo',
        description: 'Barbería familiar',
        themeIndex: 2,
        logoBase64: 'abc',
        coverBase64: null,
        whatsapp: '4421234567',
        instagram: 'elclasico',
        facebook: '',
      );
      // "Datos del negocio" no toca el diseño...
      expect(decorado.basicMap().containsKey('slogan'), isFalse);
      // ...y "Mi sitio" no toca los datos generales.
      expect(decorado.siteMap().containsKey('name'), isFalse);

      final leido = Business.fromMap('b1', decorado.toMap());
      expect(leido.slogan, 'Cortes con estilo');
      expect(leido.logoBase64, 'abc');
      expect(leido.hasSiteDesign, isTrue);
      expect(leido.colors, sitePalettes[2]);
    });

    test('sin color elegido se usan los de la categoría', () {
      expect(barberia.colors, BusinessCategory.barberias.colors);
      expect(barberia.hasSiteDesign, isFalse);
    });

    test('un perfil puede tener las dos interfaces', () {
      final p = UserProfile.fromMap('u1', {
        'name': 'Ana',
        'email': 'ana@gmail.com',
        'isClient': true,
        'isBusiness': true,
        'mode': 'business',
      });
      expect(p.isClient && p.isBusiness, isTrue);
      expect(p.mode, AppMode.business);
    });
  });

  group('Pagos', () {
    test('lee los estados que escribe el servidor', () {
      expect(AppointmentStatus.parse('pendiente_pago'), AppointmentStatus.pendientePago);
      expect(AppointmentStatus.parse('reembolsada'), AppointmentStatus.reembolsada);
      expect(AppointmentStatus.parse('expirada').label, 'Pago no completado');
      // Citas viejas sin estado se toman como confirmadas.
      expect(AppointmentStatus.parse(null), AppointmentStatus.confirmada);
    });

    test('un apartado sin pagar ocupa el horario solo mientras no vence', () {
      final t = DateTime(2026, 10, 27, 12);
      Appointment apartada(DateTime vence) => Appointment.fromMap('p1', {
            'professional': 'Luis',
            'start': Timestamp.fromDate(t),
            'minutes': 60,
            'status': 'pendiente_pago',
            'holdExpiresAt': Timestamp.fromDate(vence),
          });
      final vigente = apartada(now.add(const Duration(minutes: 20)));
      final vencida = apartada(now.subtract(const Duration(minutes: 1)));
      expect(vigente.blocksSlot(now), isTrue);
      expect(vencida.blocksSlot(now), isFalse);
      expect(
        isProfessionalFree(
            professional: 'Luis', start: t, minutes: 60, existing: [vigente], now: now),
        isFalse,
      );
      expect(
        isProfessionalFree(
            professional: 'Luis', start: t, minutes: 60, existing: [vencida], now: now),
        isTrue,
      );
    });

    test('las citas reembolsadas o con pago no completado no ocupan horario', () {
      final t = DateTime(2026, 10, 27, 12);
      for (final s in [AppointmentStatus.reembolsada, AppointmentStatus.expirada]) {
        final a = cita(id: 'x', start: t, professional: 'Luis', status: s);
        expect(a.isCancelled, isTrue);
        expect(a.blocksSlot(now), isFalse);
      }
    });

    test('lee montos en centavos del servidor', () {
      expect(fromCents(5750), 57.5);
      final o = ShopOrder.fromMap('o1', {
        'itemName': 'Cera',
        'quantity': 2,
        'totalCents': 36000,
        'status': 'pagada',
      });
      expect(o.isPaid, isTrue);
      expect(fromCents(o.totalCents), 360);
      final m = Movement.fromMap('m1', {
        'type': 'anticipo',
        'grossCents': 5750,
        'feeCents': 288,
        'netCents': 5462,
      });
      expect(m.grossCents - m.feeCents, m.netCents);
    });
  });

  group('Información del sitio', () {
    test('dice si está abierto y cuándo abre', () {
      // Lunes 26 de octubre de 2026
      expect(openingStatus(barberia, DateTime(2026, 10, 26, 12)).open, isTrue);
      expect(openingStatus(barberia, DateTime(2026, 10, 26, 12)).text, 'Abierto · cierra a las 20:00');
      expect(openingStatus(barberia, DateTime(2026, 10, 26, 8)).text, 'Cerrado · abre hoy a las 10:00');
      expect(openingStatus(barberia, DateTime(2026, 10, 26, 21)).text, 'Cerrado · abre mañana a las 10:00');
      // Sábado en la noche: el domingo cierra, abre hasta el lunes.
      expect(openingStatus(barberia, DateTime(2026, 10, 31, 21)).text, 'Cerrado · abre el lunes a las 10:00');
    });

    test('guarda y lee la ubicación del mapa', () {
      final m = {...barberia.toMap(), 'lat': 20.59, 'lng': -100.41};
      final leido = Business.fromMap('b1', m);
      expect(leido.hasLocation, isTrue);
      expect(leido.latitude, 20.59);
      // Coordenadas inválidas se ignoran.
      expect(Business.fromMap('b1', {...m, 'lat': 999}).hasLocation, isFalse);
      expect(barberia.toMap()['lat'], isNull);
    });

    test('las publicaciones pueden traer video', () {
      final p = Post.fromMap('p1', {
        'businessId': 'b1',
        'text': 'Mira el nuevo corte',
        'videoUrl': 'https://firebasestorage.googleapis.com/v0/b/x/o/posts%2Fb1%2F1.mp4',
        'videoPath': 'posts/b1/1.mp4',
      });
      expect(p.hasVideo, isTrue);
      expect(p.toMap()['videoPath'], 'posts/b1/1.mp4');
      expect(Post.fromMap('p2', {'text': 'Solo texto'}).hasVideo, isFalse);
    });
  });

  group('Cerca de ti y catálogo', () {
    test('calcula distancias y las escribe bonito', () {
      // Jardín Zenea a Plaza de Armas (Querétaro): unos 400 m
      final d = distanceMeters(20.5926, -100.3926, 20.5934, -100.3889);
      expect(d, inInclusiveRange(300, 500));
      expect(distanceText(437), 'a 440 m');
      expect(distanceText(1234), 'a 1.2 km');
      expect(distanceText(15400), 'a 15 km');
    });

    test('ordena los negocios del más cercano al más lejano', () {
      final puntos = {'A': (lat: 20.60, lng: -100.39), 'B': (lat: 20.59, lng: -100.39), 'C': (lat: 21.50, lng: -100.39)};
      final r = nearestFirst<String>(
        items: puntos.keys,
        locate: (k) => puntos[k],
        userLat: 20.589,
        userLng: -100.39,
      );
      expect(r.map((e) => e.item).toList(), ['B', 'A']); // C está a 100 km
    });

    test('agrupa los servicios por clasificación', () {
      const items = [
        Item(id: '1', kind: ItemKind.servicio, name: 'Corte', price: 150, section: 'Cortes'),
        Item(id: '2', kind: ItemKind.servicio, name: 'Barba', price: 100, section: 'Barba'),
        Item(id: '3', kind: ItemKind.servicio, name: 'Corte niño', price: 120, section: 'Cortes'),
        Item(id: '4', kind: ItemKind.servicio, name: 'Ceja', price: 50),
      ];
      final g = groupBySection(items);
      expect(g.map((x) => x.name).toList(), ['Cortes', 'Barba', 'Otros']);
      expect(g.first.items.length, 2);
      expect(groupBySection(const [Item(id: '9', kind: ItemKind.servicio, name: 'X', price: 1)]).single.name, 'Todos');
    });
  });
}
