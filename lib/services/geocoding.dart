import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' show LatLng;

/// Convierte una dirección escrita en coordenadas usando OpenStreetMap
/// (Nominatim). Es gratis y no necesita llave, pero pide no hacer más de una
/// búsqueda por segundo: por eso se guarda lo ya buscado.
class Geocoding {
  Geocoding._();

  static final Map<String, LatLng?> _cache = {};

  /// Centro de Querétaro (se usa si todavía no hay ubicación).
  static const LatLng queretaro = LatLng(20.5888, -100.3899);

  static Future<LatLng?> search(String address) async {
    final q = address.trim();
    if (q.length < 4) return null;
    final key = q.toLowerCase();
    if (_cache.containsKey(key)) return _cache[key];

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': q,
      'format': 'jsonv2',
      'limit': '1',
      'countrycodes': 'mx',
      'accept-language': 'es',
    });
    try {
      final res = await http.get(
        uri,
        // En el navegador no se puede cambiar el User-Agent; en el teléfono sí.
        headers: kIsWeb ? const {} : const {'User-Agent': 'Bookly/1.0 (proyecto escolar UAQ)'},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final list = jsonDecode(res.body);
      LatLng? point;
      if (list is List && list.isNotEmpty && list.first is Map) {
        final first = list.first as Map;
        final lat = double.tryParse('${first['lat']}');
        final lon = double.tryParse('${first['lon']}');
        if (lat != null && lon != null) point = LatLng(lat, lon);
      }
      _cache[key] = point;
      return point;
    } catch (_) {
      return null; // sin internet o el servicio no respondió
    }
  }
}
