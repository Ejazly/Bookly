/// Configuración de anuncios (Google AdMob).
///
/// MIENTRAS DESARROLLAS deja los IDs de PRUEBA de Google que están aquí:
/// muestran anuncios de ejemplo y no cuentan como clics reales. Hacer clic en
/// anuncios reales propios puede hacer que Google cierre tu cuenta de AdMob.
///
/// Cuando publiques en Play Store:
///  1. Crea tu cuenta en https://admob.google.com y agrega la app "Bookly".
///  2. Crea un bloque de anuncios tipo "Banner" y pega su ID en [androidBanner].
///  3. Cambia el ID de la app en android/app/src/main/AndroidManifest.xml
///     (la línea com.google.android.gms.ads.APPLICATION_ID).
class AdsConfig {
  /// false = la app no muestra ningún anuncio.
  static const bool enabled = true;

  // IDs de PRUEBA oficiales de Google (cámbialos por los tuyos al publicar).
  static const String androidBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const String iosBanner = 'ca-app-pub-3940256099942544/2934735716';
}
