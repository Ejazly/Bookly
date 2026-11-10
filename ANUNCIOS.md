# Anuncios (Google AdMob) y publicación en Play Store

Bookly es **gratis con anuncios**. Los anuncios salen solo en Android/iPhone (en la web no):

- **Inicio**: un banner debajo de "Cerca de ti".
- **Novedades**: un anuncio cada dos negocios.
- **Nunca** en pantallas de pago, registro ni billetera.

## Qué anuncios se permiten

1. **En el código** (`lib/ads/ads_mobile.dart`) se piden solo anuncios con clasificación
   **G (todo público)**. Eso excluye anuncios para adultos.
2. **En la consola de AdMob** hay que bloquear categorías sensibles:
   AdMob → *Bloquear controles* → *Todas las apps* → **Categorías sensibles**. Bloquea:
   - Apuestas y juegos de azar (casinos, loterías)
   - Citas
   - Contenido sexual / sugerente
   - Drogas, alcohol y tabaco (si no los quieres)
   - Cualquier otra que no quieras
   AdMob, por sus propias políticas, ya no permite anuncios ilegales ni pornografía.

## Pasos

1. Crea tu cuenta en <https://admob.google.com> y agrega la app **Bookly** (Android).
2. Crea un bloque de anuncios **Banner** y copia su ID (`ca-app-pub-XXXX/YYYY`).
3. Pégalo en `lib/config/ads_config.dart` (`androidBanner`).
4. En `android/app/src/main/AndroidManifest.xml` cambia el valor de
   `com.google.android.gms.ads.APPLICATION_ID` por el **ID de tu app** (`ca-app-pub-XXXX~ZZZZ`).
5. Mientras pruebas, deja los IDs de prueba que ya están: **no toques tus propios anuncios
   reales**, Google puede cerrar la cuenta por clics inválidos.

## Play Store (lo que pide Google)

- Cuenta de desarrollador: **US$25, un solo pago**.
- Cuentas **personales** nuevas: antes de publicar hay que hacer una **prueba cerrada con al
  menos 12 personas durante 14 días seguidos**. Junta a 15 o más compañeros con Android.
- En la ficha: marcar **"Contiene anuncios"**, llenar **Seguridad de los datos** (correo,
  ubicación aproximada, fotos/videos) y poner un **enlace a la política de privacidad**.
- Como se pueden crear cuentas, Google pide que la persona pueda **borrar su cuenta**.
- Los pagos con Stripe están permitidos porque son servicios físicos (citas y productos),
  no contenido digital.
- Para cobrar dinero real: verificar la cuenta de Stripe y cambiar a la llave `sk_live_`.
