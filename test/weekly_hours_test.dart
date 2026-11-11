// Pruebas del horario distinto por día (weeklyHours).
// Los mismos casos y resultados están en functions/test/schedule.test.js:
// si cambias uno, cambia el otro para que Dart y JS sigan dando lo mismo.

import 'package:flutter_test/flutter_test.dart';

import 'package:bookly/logic/schedule.dart';
import 'package:bookly/models/models.dart';

List<int> range(int a, int b) => [for (var i = a; i <= b; i++) i];

// Semana del lunes 26 de octubre de 2026 (offset 0 = lunes ... 6 = domingo).
DateTime day(int offset) => DateTime(2026, 10, 26 + offset);

const staff = [
  StaffMember(name: 'Evelyn', startHour: 10, endHour: 16, daysOff: {DateTime.monday}),
  StaffMember(name: 'Sandy', startHour: 14, endHour: 20),
];

const legacy = Business(
  id: 'l',
  ownerUid: 'l',
  ownerEmail: '',
  name: 'Antes',
  category: BusinessCategory.barberias,
  address: '',
  phone: '',
  openHour: 10,
  closeHour: 20,
  closedWeekdays: {DateTime.sunday},
  professionals: [],
  staffMembers: staff,
);

const weekly = Business(
  id: 'w',
  ownerUid: 'w',
  ownerEmail: '',
  name: 'Por día',
  category: BusinessCategory.barberias,
  address: '',
  phone: '',
  openHour: 9,
  closeHour: 19,
  closedWeekdays: {DateTime.sunday},
  professionals: [],
  staffMembers: staff,
  weeklyHours: {
    1: DayHours(10, 14),
    2: DayHours(9, 19),
    3: DayHours(9, 19),
    4: DayHours(9, 19),
    5: DayHours(9, 19),
    6: DayHours(10, 16),
    7: null,
  },
);

List<int> slotHours(Business b, int offset, int minutes) =>
    [for (final t in slotsFor(b, minutes, day(offset))) t.hour];

List<int> memberHours(Business b, int offset, int minutes, String name) =>
    [for (final t in slotsForMember(b, b.memberNamed(name)!, minutes, day(offset))) t.hour];

void main() {
  test('sin weeklyHours el negocio se comporta igual que antes', () {
    expect(legacy.weeklyHours, isNull);
    expect(legacy.hoursForWeekday(2), const DayHours(10, 20));
    expect(legacy.hoursForWeekday(7), isNull);
    expect(slotHours(legacy, 1, 60), range(10, 19));
    expect(slotHours(legacy, 6, 60), isEmpty);
  });

  test('weeklyHours: lunes distinto de sábado y domingo cerrado', () {
    expect(slotHours(weekly, 0, 60), [10, 11, 12, 13]);
    expect(slotHours(weekly, 1, 60), range(9, 18));
    expect(slotHours(weekly, 5, 60), range(10, 15));
    expect(slotHours(weekly, 6, 60), isEmpty);
    expect(slotHours(weekly, 0, 120), [10, 11, 12]);
    expect(slotHours(weekly, 5, 120), range(10, 14));
    expect(weekly.isOpenOn(day(6)), false);
  });

  test('weeklyHours: turnos del personal y días de descanso', () {
    expect(memberHours(weekly, 0, 60, 'Evelyn'), isEmpty);
    expect(memberHours(weekly, 0, 60, 'Sandy'), isEmpty);
    expect(memberHours(weekly, 1, 60, 'Evelyn'), range(10, 15));
    expect(memberHours(weekly, 1, 60, 'Sandy'), range(14, 18));
    expect(memberHours(weekly, 5, 60, 'Sandy'), [14, 15]);
    expect(memberHours(weekly, 6, 60, 'Sandy'), isEmpty);
  });

  test('weeklyHours: día ausente o inválido usa el horario general', () {
    final b = Business.fromMap('x', {
      'openHour': 10,
      'closeHour': 20,
      'closedWeekdays': [3],
      'weeklyHours': {
        '1': {'open': 12, 'close': 8},
        '2': {'open': 8, 'close': 12},
      },
    });
    expect(b.hoursForWeekday(1), const DayHours(10, 20));
    expect(b.hoursForWeekday(2), const DayHours(8, 12));
    expect(b.hoursForWeekday(3), isNull);
    expect(b.hoursForWeekday(4), const DayHours(10, 20));
  });

  test('guardar y leer weeklyHours (y no se guarda si no existe)', () {
    final leido = Business.fromMap('w', weekly.toMap());
    expect(leido.weeklyHours, weekly.weeklyHours);
    expect(leido.hoursForWeekday(7), isNull);
    expect(legacy.toMap().containsKey('weeklyHours'), false);
  });

  test('estado de apertura usa el horario del día', () {
    expect(openingStatus(weekly, DateTime(2026, 10, 26, 11)).text, 'Abierto · cierra a las 14:00');
    expect(openingStatus(weekly, DateTime(2026, 10, 31, 15)).text, 'Abierto · cierra a las 16:00');
    expect(openingStatus(weekly, DateTime(2026, 10, 26, 15)).text, 'Cerrado · abre mañana a las 9:00');
    expect(openingStatus(weekly, DateTime(2026, 10, 31, 17)).text, 'Cerrado · abre el lunes a las 10:00');
    expect(openingStatus(weekly, DateTime(2026, 10, 26, 8)).text, 'Cerrado · abre hoy a las 10:00');
  });
}
