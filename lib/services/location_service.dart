import 'package:geolocator/geolocator.dart';

enum LocationAccess { granted, denied, deniedForever, serviceOff }

/// Ubicación de la persona para "Negocios cerca de ti".
///
/// Privacidad: la ubicación SOLO se usa dentro del teléfono para calcular
/// distancias. No se guarda en la base de datos ni se manda a nadie.
class LocationService {
  LocationService._();

  /// ¿Ya dio permiso antes? (no muestra la ventana de permiso)
  static Future<bool> alreadyGranted() async {
    try {
      final p = await Geolocator.checkPermission();
      return p == LocationPermission.always || p == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  /// Pide el permiso de ubicación (muestra la ventana del sistema).
  static Future<LocationAccess> requestAccess() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return LocationAccess.serviceOff;
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      return switch (p) {
        LocationPermission.always || LocationPermission.whileInUse => LocationAccess.granted,
        LocationPermission.deniedForever => LocationAccess.deniedForever,
        _ => LocationAccess.denied,
      };
    } catch (_) {
      return LocationAccess.denied;
    }
  }

  /// Posición en vivo: avisa cada vez que la persona se mueve unos 40 m.
  static Stream<Position> positions() => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 40,
        ),
      );

  static Future<Position?> current() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 15));
    } catch (_) {
      return null;
    }
  }

  static Future<void> openSettings() => Geolocator.openAppSettings();
}
