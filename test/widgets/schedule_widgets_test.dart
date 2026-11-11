import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bookly/models/models.dart';
import 'package:bookly/widgets/schedule_widgets.dart';

import 'helpers.dart';

void main() {
  testWidgets('DayChip muestra día y responde al toque solo si está habilitado', (tester) async {
    var taps = 0;
    final date = DateTime(2026, 11, 10); // martes
    await tester.pumpWidget(wrap(SizedBox(
      height: 68,
      child: DayChip(date: date, selected: false, enabled: true, onTap: () => taps++),
    )));
    expect(find.text('10'), findsOneWidget);
    expect(find.text('Mar'), findsOneWidget);
    await tester.tap(find.text('10'));
    expect(taps, 1);

    await tester.pumpWidget(wrap(SizedBox(
      height: 68,
      child: DayChip(date: date, selected: false, enabled: false, onTap: () => taps++),
    )));
    await tester.tap(find.text('10'));
    expect(taps, 1);
  });

  testWidgets('DaySelector marca el día elegido y avisa al tocar otro', (tester) async {
    final days = [for (var i = 0; i < 5; i++) DateTime(2026, 11, 10 + i)];
    DateTime? picked;
    await tester.pumpWidget(wrap(DaySelector(
      days: days,
      selected: days[0],
      onSelected: (d) => picked = d,
      isEnabled: (d) => d.day != 12,
    )));
    expect(find.byType(DayChip), findsNWidgets(5));
    final chips = tester.widgetList<DayChip>(find.byType(DayChip)).toList();
    expect(chips[0].selected, isTrue);
    expect(chips[1].selected, isFalse);
    expect(chips[2].enabled, isFalse); // día 12 deshabilitado

    await tester.tap(find.text('11'));
    expect(picked, days[1]);
    picked = null;
    await tester.tap(find.text('12'));
    expect(picked, isNull);
  });

  testWidgets('SlotChip ocupado aparece tachado y no responde', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
        wrap(SlotChip(label: '10:00', selected: false, enabled: false, onTap: () => taps++)));
    final text = tester.widget<Text>(find.text('10:00'));
    expect(text.style?.decoration, TextDecoration.lineThrough);
    await tester.tap(find.text('10:00'));
    expect(taps, 0);
  });

  testWidgets('SlotChip libre responde al toque', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
        wrap(SlotChip(label: '11:00', selected: false, enabled: true, onTap: () => taps++)));
    await tester.tap(find.text('11:00'));
    expect(taps, 1);
  });

  testWidgets('ProChip muestra "Cualquiera" cuando no hay nombre', (tester) async {
    await tester.pumpWidget(wrap(ProChip(name: null, selected: false, onTap: () {})));
    expect(find.text('Cualquiera'), findsOneWidget);
  });

  testWidgets('ProChip muestra el nombre y responde al toque', (tester) async {
    var taps = 0;
    await tester.pumpWidget(wrap(ProChip(name: 'Ana', selected: true, onTap: () => taps++)));
    expect(find.text('Ana'), findsOneWidget);
    await tester.tap(find.text('Ana'));
    expect(taps, 1);
  });

  group('StaffSlotPicker', () {
    // Un día futuro para que ningún horario "ya haya pasado".
    final n = DateTime.now().add(const Duration(days: 10));
    final day = DateTime(n.year, n.month, n.day);

    testWidgets('si el negocio cierra ese día lo avisa', (tester) async {
      final b = Business(
        id: 'b',
        ownerUid: 'u',
        ownerEmail: 'e@x.com',
        name: 'N',
        category: BusinessCategory.otro,
        address: 'a',
        phone: 'p',
        openHour: 10,
        closeHour: 14,
        closedWeekdays: {day.weekday},
        professionals: const [],
      );
      await tester.pumpWidget(wrap(StaffSlotPicker(
        business: b,
        minutes: 60,
        day: day,
        existing: const [],
        selectedTime: null,
        selectedPro: null,
        onSelected: (_, __) {},
      )));
      expect(find.textContaining('no abre este día'), findsOneWidget);
    });

    testWidgets('muestra horarios por persona y avisa al elegir uno', (tester) async {
      final b = testBusiness(staff: const [
        StaffMember(name: 'Ana', startHour: 10, endHour: 12),
      ]);
      DateTime? time;
      String? pro;
      await tester.pumpWidget(wrap(StaffSlotPicker(
        business: b,
        minutes: 60,
        day: day,
        existing: const [],
        selectedTime: null,
        selectedPro: null,
        onSelected: (t, p) {
          time = t;
          pro = p;
        },
      )));
      expect(find.text('Te atiende Ana'), findsOneWidget);
      expect(find.byType(SlotChip), findsWidgets);
      expect(find.text('10:00'), findsOneWidget);
      await tester.tap(find.text('10:00'));
      expect(pro, 'Ana');
      expect(time, DateTime(day.year, day.month, day.day, 10));
    });

    testWidgets('si nadie del personal trabaja ese día lo avisa', (tester) async {
      final b = testBusiness(staff: [
        StaffMember(name: 'Ana', startHour: 10, endHour: 12, daysOff: {day.weekday}),
      ]);
      await tester.pumpWidget(wrap(StaffSlotPicker(
        business: b,
        minutes: 60,
        day: day,
        existing: const [],
        selectedTime: null,
        selectedPro: null,
        onSelected: (_, __) {},
      )));
      expect(find.textContaining('Nadie del personal'), findsOneWidget);
    });
  });
}
