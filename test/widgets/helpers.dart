import 'package:flutter/material.dart';
import 'package:bookly/models/models.dart';

/// PNG de 1x1 píxel en base64 (para probar imágenes sin archivos).
const String pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

/// Envuelve un widget en una app mínima con ancho fijo, alineado arriba a la izquierda.
Widget wrap(Widget child, {double width = 400}) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    );

Business testBusiness({List<StaffMember> staff = const [], String slogan = ''}) => Business(
      id: 'b1',
      ownerUid: 'u1',
      ownerEmail: 'dueno@example.com',
      name: 'Barbería Prueba',
      category: BusinessCategory.barberias,
      address: 'Calle 1',
      phone: '4421234567',
      openHour: 10,
      closeHour: 14,
      closedWeekdays: const {},
      professionals: const [],
      staffMembers: staff,
      slogan: slogan,
    );

Item testItem(String name,
        {String section = '',
        ItemKind kind = ItemKind.servicio,
        double price = 100,
        int stock = 0}) =>
    Item(id: name, kind: kind, name: name, price: price, section: section, stock: stock);
