// Cálculos de distancia (funciones puras, se prueban con `flutter test`).

import 'dart:math' as math;

/// Distancia en metros entre dos puntos (fórmula de Haversine).
double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const earth = 6371000.0; // radio de la Tierra en metros
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return earth * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// "a 350 m", "a 1.2 km", "a 15 km".
String distanceText(double meters) {
  if (meters < 1000) {
    final rounded = (meters / 10).round() * 10;
    return 'a ${rounded < 10 ? 10 : rounded} m';
  }
  final km = meters / 1000;
  return km < 10 ? 'a ${km.toStringAsFixed(1)} km' : 'a ${km.round()} km';
}

/// Minutos aproximados caminando (5 km/h).
int walkingMinutes(double meters) => math.max(1, (meters / 83.3).round());

/// Un negocio con su distancia a la persona.
class NearbyEntry<T> {
  const NearbyEntry(this.item, this.meters);
  final T item;
  final double meters;
}

/// Ordena por cercanía y se queda con los que están dentro de [radiusMeters].
/// Si ninguno está dentro, regresa los [fallback] más cercanos para que la
/// sección nunca se vea vacía.
List<NearbyEntry<T>> nearestFirst<T>({
  required Iterable<T> items,
  required ({double lat, double lng})? Function(T item) locate,
  required double userLat,
  required double userLng,
  double radiusMeters = 5000,
  int fallback = 3,
  int limit = 12,
}) {
  final all = <NearbyEntry<T>>[];
  for (final it in items) {
    final p = locate(it);
    if (p == null) continue;
    all.add(NearbyEntry(it, distanceMeters(userLat, userLng, p.lat, p.lng)));
  }
  all.sort((a, b) => a.meters.compareTo(b.meters));
  final inside = all.where((e) => e.meters <= radiusMeters).toList();
  final result = inside.isNotEmpty ? inside : all.take(fallback).toList();
  return result.take(limit).toList();
}
