// Búsqueda de negocios por nombre, servicio, producto, clasificación y categoría.
// Funciones puras (sin Firebase ni Flutter) para poder probarlas fácil.

/// Quita acentos y mayúsculas: "Corte de Cabello" -> "corte de cabello".
String normalizeText(String s) {
  const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const to = 'aaaaaeeeeiiiiooooouuuunc';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b.toString();
}

/// Palabras de la búsqueda, ya normalizadas y sin espacios repetidos.
List<String> searchTokens(String query) => normalizeText(query)
    .split(RegExp(r'[^a-z0-9]+'))
    .where((t) => t.isNotEmpty)
    .toList();

/// Servicio o producto de un negocio, con solo lo necesario para buscar.
class SearchItem {
  const SearchItem({required this.name, this.section = '', this.isService = true});

  final String name;
  final String section;
  final bool isService;
}

/// Dónde coincidió la búsqueda.
enum SearchField { name, service, product, section, category, address }

class SearchHit {
  const SearchHit({required this.score, required this.field, this.item});

  final double score;
  final SearchField field;

  /// Servicio/producto que coincidió (null si coincidió el negocio o su categoría).
  final SearchItem? item;

  /// Texto para mostrar bajo el resultado, o null si no hace falta.
  String? get matchLabel {
    final it = item;
    if (it == null) return null;
    if (field == SearchField.section && it.section.trim().isNotEmpty) {
      return '${it.section.trim()}: ${it.name}';
    }
    return it.name;
  }
}

/// true si TODAS las palabras de la búsqueda aparecen en [text].
bool _allTokensIn(List<String> tokens, String text) {
  if (tokens.isEmpty) return false;
  final t = normalizeText(text);
  return tokens.every(t.contains);
}

/// Calcula cómo coincide un negocio con la búsqueda. Regresa null si no coincide.
/// Prioridad: nombre del negocio > servicio > producto > clasificación > categoría > dirección.
/// Si la búsqueda está vacía regresa null (quien llama decide mostrar todo).
SearchHit? matchBusiness({
  required String query,
  required String name,
  required String categoryLabel,
  String address = '',
  List<SearchItem> items = const [],
}) {
  final tokens = searchTokens(query);
  if (tokens.isEmpty) return null;

  SearchHit? best;
  void consider(SearchHit h) {
    if (best == null || h.score > best!.score) best = h;
  }

  // El nombre junto con la categoría permite "barberia juan".
  if (_allTokensIn(tokens, name)) {
    consider(const SearchHit(score: 6, field: SearchField.name));
  } else if (!_allTokensIn(tokens, categoryLabel) &&
      _allTokensIn(tokens, '$name $categoryLabel')) {
    consider(const SearchHit(score: 5, field: SearchField.name));
  }
  for (final it in items) {
    if (_allTokensIn(tokens, it.name)) {
      consider(SearchHit(
        score: it.isService ? 4 : 3.5,
        field: it.isService ? SearchField.service : SearchField.product,
        item: it,
      ));
    } else if (it.section.trim().isNotEmpty &&
        _allTokensIn(tokens, '${it.section} ${it.name}')) {
      consider(SearchHit(
        score: _allTokensIn(tokens, it.section) ? 3 : 3.2,
        field: SearchField.section,
        item: it,
      ));
    }
  }
  if (_allTokensIn(tokens, categoryLabel)) {
    consider(const SearchHit(score: 2, field: SearchField.category));
  }
  if (_allTokensIn(tokens, address)) {
    consider(const SearchHit(score: 1, field: SearchField.address));
  }
  return best;
}

/// Ordena de mayor a menor puntaje (estable: a igual puntaje conserva el orden).
List<T> rankByScore<T>(List<(T, SearchHit)> hits) {
  final indexed = [for (var i = 0; i < hits.length; i++) (i, hits[i])];
  indexed.sort((a, b) {
    final c = b.$2.$2.score.compareTo(a.$2.$2.score);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2.$1];
}
