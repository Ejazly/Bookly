import 'package:flutter_test/flutter_test.dart';
import 'package:bookly/models/models.dart';
import 'package:bookly/widgets/common.dart';
import 'package:bookly/widgets/images.dart';
import 'package:bookly/widgets/post_card.dart';

import 'helpers.dart';

Post _post({String? image}) => Post(
      id: 'p1',
      businessId: 'b1',
      businessName: 'Barbería Prueba',
      category: BusinessCategory.barberias,
      text: 'Nuevo corte de temporada',
      imageBase64: image,
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
    );

void main() {
  testWidgets('muestra negocio, texto y hace cuánto se publicó', (tester) async {
    await tester.pumpWidget(wrap(PostCard(post: _post()), width: 600));
    expect(find.text('Barbería Prueba'), findsOneWidget);
    expect(find.text('Nuevo corte de temporada'), findsOneWidget);
    expect(find.text('Hace 5 min'), findsOneWidget);
    expect(find.byType(AdaptiveImage), findsNothing);
  });

  testWidgets('con foto usa AdaptiveImage', (tester) async {
    await tester.pumpWidget(wrap(PostCard(post: _post(image: pngBase64)), width: 600));
    expect(find.byType(AdaptiveImage), findsOneWidget);
  });

  testWidgets('el ancho máximo es 504 y va alineado a la izquierda', (tester) async {
    await tester.pumpWidget(wrap(PostCard(post: _post()), width: 800));
    final rect = tester.getRect(find.byType(AppCard));
    expect(rect.left, 0);
    expect(rect.width, 504);
  });

  testWidgets('showBusiness=false oculta el nombre del negocio', (tester) async {
    await tester.pumpWidget(wrap(PostCard(post: _post(), showBusiness: false), width: 600));
    expect(find.text('Barbería Prueba'), findsNothing);
    expect(find.text('Hace 5 min'), findsOneWidget);
  });

  testWidgets('el botón eliminar solo aparece para el dueño', (tester) async {
    var deleted = 0;
    await tester.pumpWidget(wrap(PostCard(post: _post(), onDelete: () => deleted++), width: 600));
    await tester.tap(find.byTooltip('Eliminar'));
    expect(deleted, 1);

    await tester.pumpWidget(wrap(PostCard(post: _post()), width: 600));
    expect(find.byTooltip('Eliminar'), findsNothing);
  });

  testWidgets('"Ver negocio y reservar" aparece con onOpenBusiness', (tester) async {
    var opened = 0;
    await tester
        .pumpWidget(wrap(PostCard(post: _post(), onOpenBusiness: () => opened++), width: 600));
    await tester.tap(find.text('Ver negocio y reservar'));
    expect(opened, 1);
  });
}
