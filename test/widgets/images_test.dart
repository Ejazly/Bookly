import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bookly/widgets/images.dart';

import 'helpers.dart';

void main() {
  group('Base64Image', () {
    testWidgets('sin datos muestra el ícono de relleno', (tester) async {
      await tester.pumpWidget(wrap(const Base64Image(data: null, width: 50, height: 50)));
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('con base64 inválido muestra el relleno', (tester) async {
      await tester.pumpWidget(
          wrap(const Base64Image(data: '%%%no-es-base64%%%', width: 50, height: 50)));
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    });

    testWidgets('con una imagen válida muestra Image', (tester) async {
      await tester.pumpWidget(wrap(const Base64Image(data: pngBase64, width: 50, height: 50)));
      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(Icons.image_outlined), findsNothing);
    });

    testWidgets('usa el ícono personalizado', (tester) async {
      await tester.pumpWidget(wrap(const Base64Image(data: null, placeholderIcon: Icons.store)));
      expect(find.byIcon(Icons.store), findsOneWidget);
    });
  });

  group('AdaptiveImage', () {
    testWidgets('con datos inválidos no dibuja nada', (tester) async {
      await tester.pumpWidget(wrap(const AdaptiveImage(data: '%%%')));
      expect(find.byType(Image), findsNothing);
      expect(find.byType(AspectRatio), findsNothing);
    });

    testWidgets('con una imagen cuadrada ocupa el ancho con proporción 1:1', (tester) async {
      await tester.pumpWidget(wrap(const AdaptiveImage(data: pngBase64), width: 300));
      // Deja que termine de medirse la imagen (decodificación real, asíncrona).
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);
      final size = tester.getSize(find.byType(AdaptiveImage));
      expect(size.width, 300);
      expect(size.height, closeTo(300, 0.5));
    });
  });

  group('FramedImage', () {
    testWidgets('con datos inválidos no muestra imágenes', (tester) async {
      await tester.pumpWidget(wrap(const SizedBox(height: 100, child: FramedImage(data: '%%%'))));
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('muestra la foto completa sobre la misma foto desenfocada', (tester) async {
      await tester
          .pumpWidget(wrap(const SizedBox(height: 100, child: FramedImage(data: pngBase64))));
      expect(find.byType(Image), findsNWidgets(2)); // fondo borroso + foto completa
      expect(find.byType(ImageFiltered), findsOneWidget);
      final fits = tester.widgetList<Image>(find.byType(Image)).map((i) => i.fit).toList();
      expect(fits, containsAll([BoxFit.cover, BoxFit.contain]));
    });
  });

  group('ImagePickerBox', () {
    testWidgets('sin imagen muestra la etiqueta para agregar', (tester) async {
      await tester.pumpWidget(
          wrap(ImagePickerBox(value: null, onChanged: (_) {}, label: 'Agregar logo')));
      expect(find.text('Agregar logo'), findsOneWidget);
    });

    testWidgets('con imagen permite quitarla', (tester) async {
      String? result = 'x';
      await tester
          .pumpWidget(wrap(ImagePickerBox(value: pngBase64, onChanged: (v) => result = v)));
      expect(find.byTooltip('Quitar imagen'), findsOneWidget);
      await tester.tap(find.byTooltip('Quitar imagen'));
      expect(result, isNull);
    });
  });
}
