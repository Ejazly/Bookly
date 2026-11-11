import 'package:flutter_test/flutter_test.dart';

import 'package:bookly/logic/search.dart';

void main() {
  const corte = SearchItem(name: 'Corte de cabello', section: 'Cortes');
  const barba = SearchItem(name: 'Arreglo de barba', section: 'Barba');
  const gel = SearchItem(name: 'Gel fijador', isService: false);

  SearchHit? buscar(String q, {String name = 'Negocio', List<SearchItem> items = const []}) =>
      matchBusiness(
        query: q,
        name: name,
        categoryLabel: 'Barberías',
        address: 'Calle Juárez 12, Querétaro',
        items: items,
      );

  test('normalizeText quita acentos y mayúsculas', () {
    expect(normalizeText('  Corte de CABELLO Ñandú Á'), '  corte de cabello nandu a');
  });

  test('searchTokens separa palabras', () {
    expect(searchTokens('  Corte,  de   Cabello '), ['corte', 'de', 'cabello']);
    expect(searchTokens('   '), isEmpty);
  });

  test('búsqueda vacía no devuelve coincidencia', () {
    expect(buscar('  ', items: [corte]), isNull);
  });

  test('coincide por servicio y muestra cuál', () {
    final h = buscar('corte de cabello', items: [barba, corte])!;
    expect(h.field, SearchField.service);
    expect(h.matchLabel, 'Corte de cabello');
  });

  test('ignora acentos y mayúsculas', () {
    expect(buscar('BARBERIAS'), isNotNull); // categoría
    expect(buscar('Corté', items: [corte]), isNotNull);
  });

  test('todas las palabras deben coincidir, en cualquier orden', () {
    expect(buscar('cabello corte', items: [corte]), isNotNull);
    expect(buscar('corte pestañas', items: [corte]), isNull);
  });

  test('coincide por clasificación', () {
    final h = buscar('cortes', items: [
      const SearchItem(name: 'Fade', section: 'Cortes'),
    ])!;
    expect(h.field, SearchField.section);
    expect(h.matchLabel, 'Cortes: Fade');
  });

  test('productos coinciden pero con menos prioridad que servicios', () {
    final p = buscar('gel', items: [gel])!;
    expect(p.field, SearchField.product);
    final s = buscar('gel', items: [gel, const SearchItem(name: 'Gel acrílico')])!;
    expect(s.field, SearchField.service);
  });

  test('ranking: nombre > servicio > categoría', () {
    final porNombre = buscar('corte', name: 'Corte Fino')!;
    final porServicio = buscar('corte', items: [corte])!;
    final porCategoria = buscar('barberias')!;
    expect(porNombre.score, greaterThan(porServicio.score));
    expect(porServicio.score, greaterThan(porCategoria.score));
  });

  test('nombre + categoría juntos', () {
    expect(buscar('barberia juan', name: 'Juan')!.field, SearchField.name);
  });

  test('coincidencia por dirección es la más baja', () {
    final h = buscar('juarez')!;
    expect(h.field, SearchField.address);
  });

  test('sin coincidencias regresa null', () {
    expect(buscar('sushi', items: [corte, gel]), isNull);
  });

  test('rankByScore ordena y es estable', () {
    final a = buscar('corte', name: 'Corte Fino')!;
    final b = buscar('corte', items: [corte])!;
    final c = buscar('corte', items: [corte])!;
    expect(rankByScore([('b', b), ('c', c), ('a', a)]), ['a', 'b', 'c']);
  });
}
