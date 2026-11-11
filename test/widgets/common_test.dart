import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bookly/theme/app_colors.dart';
import 'package:bookly/widgets/common.dart';

import 'helpers.dart';

void main() {
  testWidgets('StatusBadge muestra su texto', (tester) async {
    await tester.pumpWidget(wrap(const StatusBadge('Abierto')));
    expect(find.text('Abierto'), findsOneWidget);
  });

  testWidgets('PrimaryButton llama onPressed al tocarlo', (tester) async {
    var taps = 0;
    await tester.pumpWidget(wrap(PrimaryButton(label: 'Guardar', onPressed: () => taps++)));
    await tester.tap(find.text('Guardar'));
    expect(taps, 1);
  });

  testWidgets('PrimaryButton con loading muestra indicador y no responde', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
        wrap(PrimaryButton(label: 'Guardar', loading: true, onPressed: () => taps++)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Guardar'), findsNothing);
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    expect(taps, 0);
  });

  testWidgets('PrimaryButton con onPressed null queda deshabilitado', (tester) async {
    await tester.pumpWidget(wrap(const PrimaryButton(label: 'Guardar', onPressed: null)));
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('SectionLabel pone el texto en mayúsculas', (tester) async {
    await tester.pumpWidget(wrap(const SectionLabel('Mis citas')));
    expect(find.text('MIS CITAS'), findsOneWidget);
  });

  testWidgets('AppCard responde al toque', (tester) async {
    var taps = 0;
    await tester.pumpWidget(wrap(AppCard(onTap: () => taps++, child: const Text('Hola'))));
    await tester.tap(find.text('Hola'));
    expect(taps, 1);
  });

  testWidgets('EmptyMessage muestra ícono, texto y acción', (tester) async {
    await tester.pumpWidget(wrap(EmptyMessage(
      icon: Icons.event_busy,
      text: 'Sin citas',
      action: TextButton(onPressed: () {}, child: const Text('Buscar')),
    )));
    expect(find.text('Sin citas'), findsOneWidget);
    expect(find.byIcon(Icons.event_busy), findsOneWidget);
    expect(find.text('Buscar'), findsOneWidget);
  });

  testWidgets('MaxWidth limita el ancho del contenido', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MaxWidth(width: 300, child: Container(key: const Key('c'), height: 20)),
      ),
    ));
    expect(tester.getSize(find.byKey(const Key('c'))).width, 300);
  });

  testWidgets('BusinessCard muestra nombre, eslogan, "Nuevo en Bookly" y responde al toque',
      (tester) async {
    var taps = 0;
    final b = testBusiness(slogan: 'El mejor corte');
    // Abierto: 11:00 (el negocio abre de 10 a 14). Ancho 900 porque la fuente de
    // pruebas (Ahem) es más ancha que la real y con 400 se desborda la fila.
    await tester.pumpWidget(wrap(BusinessCard(
      business: b,
      now: DateTime(2026, 11, 10, 11),
      onTap: () => taps++,
    ), width: 900));
    expect(find.text('Barbería Prueba'), findsOneWidget);
    expect(find.text('El mejor corte'), findsOneWidget);
    expect(find.text('Nuevo en Bookly'), findsOneWidget);
    expect(find.text('Abierto'), findsOneWidget);
    await tester.tap(find.byType(BusinessCard));
    expect(taps, 1);
  });

  testWidgets('BusinessCard muestra Cerrado fuera de horario', (tester) async {
    await tester.pumpWidget(wrap(BusinessCard(
      business: testBusiness(),
      now: DateTime(2026, 11, 10, 20),
      onTap: () {},
    ), width: 900));
    expect(find.text('Cerrado'), findsOneWidget);
  });

  testWidgets('GradientBox aplica el tamaño', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: const GradientBox(colors: [AppColors.teal, AppColors.blue], width: 50, height: 30),
      ),
    ));
    expect(tester.getSize(find.byType(GradientBox)), const Size(50, 30));
  });

  test('streamStatus: error, cargando y con datos', () {
    expect(
        streamStatus(const AsyncSnapshot<Object?>.withError(
            ConnectionState.done, 'boom', StackTrace.empty)),
        isA<Padding>());
    expect(streamStatus(const AsyncSnapshot<Object?>.waiting()), isA<Padding>());
    expect(streamStatus(const AsyncSnapshot<Object?>.withData(ConnectionState.active, 1)), isNull);
  });
}
