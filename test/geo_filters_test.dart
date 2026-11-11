import 'package:flutter_test/flutter_test.dart';
import 'package:bookly/logic/geo.dart';

void main() {
  // Puntos sobre una línea: ~111 m por cada 0.001 de latitud.
  const userLat = 20.0, userLng = -100.0;
  final items = <({String id, double lat, bool open})>[
    (id: 'a', lat: 20.005, open: true), // ~0.55 km
    (id: 'b', lat: 20.02, open: false), // ~2.2 km
    (id: 'c', lat: 20.03, open: true), // ~3.3 km
    (id: 'd', lat: 20.1, open: true), // ~11 km
  ];
  List<String> run(double radius, {bool onlyOpen = false, int limit = 12}) => filterNearby(
        items: items,
        locate: (i) => (lat: i.lat, lng: userLng),
        userLat: userLat,
        userLng: userLng,
        radiusMeters: radius,
        onlyOpen: onlyOpen,
        isOpen: (i) => i.open,
        limit: limit,
      ).map((e) => e.item.id).toList();

  test('filtra por radio y ordena por cercanía', () {
    expect(run(1000), ['a']);
    expect(run(3000), ['a', 'b']);
    expect(run(5000), ['a', 'b', 'c']);
    expect(run(10000), ['a', 'b', 'c']);
    expect(run(20000), ['a', 'b', 'c', 'd']);
  });

  test('sin resultados no rellena con negocios lejanos', () {
    expect(run(100), isEmpty);
  });

  test('solo abiertos', () {
    expect(run(5000, onlyOpen: true), ['a', 'c']);
    expect(run(1000, onlyOpen: true), ['a']);
    expect(run(2500, onlyOpen: true), ['a']);
  });

  test('solo abiertos sin función isOpen no deja nada', () {
    final r = filterNearby<int>(
      items: [1],
      locate: (_) => (lat: 20.0, lng: -100.0),
      userLat: 20.0,
      userLng: -100.0,
      radiusMeters: 1000,
      onlyOpen: true,
    );
    expect(r, isEmpty);
  });

  test('el límite se aplica después de filtrar', () {
    expect(run(20000, onlyOpen: true, limit: 2), ['a', 'c']);
  });

  test('ignora negocios sin ubicación', () {
    final r = filterNearby<int>(
      items: [1, 2],
      locate: (i) => i == 1 ? null : (lat: 20.0, lng: -100.0),
      userLat: 20.0,
      userLng: -100.0,
      radiusMeters: 1000,
    );
    expect(r.map((e) => e.item), [2]);
  });

  test('radiusLabel', () {
    expect(radiusLabel(500), '500 m');
    expect(radiusLabel(1000), '1 km');
    expect(radiusLabel(3000), '3 km');
    expect(radiusLabel(2500), '2.5 km');
  });
}
