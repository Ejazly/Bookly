import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';

/// Abre una dirección fuera de la app (Google Maps, WhatsApp, teléfono...).
Future<bool> openExternal(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// "Cómo llegar" en Google Maps: con coordenadas si las hay; si no, con la dirección.
Uri directionsUri(Business b) => Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': b.hasLocation ? '${b.latitude},${b.longitude}' : '${b.name}, ${b.address}',
    });

Uri phoneUri(String phone) => Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^0-9+]'), ''));

/// WhatsApp: los números de 10 dígitos se toman como de México (+52).
Uri whatsappUri(String number) {
  var digits = number.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length == 10) digits = '52$digits';
  return Uri.https('wa.me', '/$digits');
}

Uri instagramUri(String user) =>
    Uri.https('www.instagram.com', '/${user.replaceAll('@', '').trim()}/');

Uri facebookUri(String page) {
  final t = page.trim();
  if (t.startsWith('http')) return Uri.tryParse(t) ?? Uri.https('www.facebook.com', '/');
  return Uri.https('www.facebook.com', '/$t');
}
