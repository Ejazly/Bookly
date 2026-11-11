import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bookly/models/models.dart';
import 'package:bookly/widgets/catalog_view.dart';

import 'helpers.dart';

void main() {
  final business = testBusiness();

  testWidgets('sin clasificación se muestra en cuadrícula (sin filtros)', (tester) async {
    await tester.pumpWidget(wrap(CatalogView(
      items: [testItem('Corte'), testItem('Barba')],
      business: business,
      onBook: (_) {},
    )));
    expect(find.byType(Wrap), findsOneWidget);
    expect(find.text('Corte'), findsOneWidget);
    expect(find.text('Barba'), findsOneWidget);
    expect(find.text('Reservar'), findsNWidgets(2));
    expect(find.textContaining('Todo ·'), findsNothing);
  });

  testWidgets('con clasificación muestra filtros y carruseles por sección', (tester) async {
    await tester.pumpWidget(wrap(CatalogView(
      items: [
        testItem('Corte', section: 'Cabello'),
        testItem('Tinte', section: 'Cabello'),
        testItem('Manicure', section: 'Uñas'),
      ],
      business: business,
      onBook: (_) {},
    )));
    expect(find.byType(Wrap), findsNothing);
    expect(find.text('Todo · 3'), findsOneWidget);
    expect(find.text('Cabello · 2'), findsOneWidget);
    expect(find.text('Uñas · 1'), findsOneWidget);
    // Títulos de sección
    expect(find.text('Cabello'), findsOneWidget);
    expect(find.text('Uñas'), findsOneWidget);
  });

  testWidgets('tocar un filtro deja solo esa clasificación', (tester) async {
    await tester.pumpWidget(wrap(CatalogView(
      items: [
        testItem('Corte', section: 'Cabello'),
        testItem('Manicure', section: 'Uñas'),
      ],
      business: business,
      onBook: (_) {},
    )));
    await tester.tap(find.text('Uñas · 1'));
    await tester.pumpAndSettle();
    expect(find.text('Manicure'), findsOneWidget);
    expect(find.text('Corte'), findsNothing);

    await tester.tap(find.text('Todo · 2'));
    await tester.pumpAndSettle();
    expect(find.text('Corte'), findsOneWidget);
  });

  testWidgets('Reservar llama onBook con el servicio', (tester) async {
    Item? booked;
    await tester.pumpWidget(wrap(CatalogView(
      items: [testItem('Corte')],
      business: business,
      onBook: (i) => booked = i,
    )));
    await tester.tap(find.text('Reservar'));
    expect(booked?.name, 'Corte');
  });

  testWidgets('productos: Comprar, Agotado y "En el negocio"', (tester) async {
    Item? bought;
    final items = [
      testItem('Cera', kind: ItemKind.producto, stock: 3),
      testItem('Shampoo', kind: ItemKind.producto, stock: 0),
    ];
    await tester.pumpWidget(wrap(CatalogView(
      items: items,
      business: business,
      onBuy: (i) => bought = i,
    )));
    expect(find.text('Comprar'), findsOneWidget);
    expect(find.text('Agotado'), findsOneWidget);
    await tester.tap(find.text('Comprar'));
    expect(bought?.name, 'Cera');

    // Sin onBuy (no se vende en línea) solo es informativo.
    await tester.pumpWidget(wrap(CatalogView(items: [items[0]], business: business)));
    expect(find.text('En el negocio'), findsOneWidget);
    expect(find.text('Comprar'), findsNothing);
  });
}
