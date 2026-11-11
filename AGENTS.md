# AGENTS.md — Contexto de Bookly para agentes de código

Este archivo es para cualquier asistente de IA o persona nueva en el proyecto: explica qué es
Bookly, cómo está armado y qué reglas no se deben romper. **Léelo antes de cambiar código.**
Lo que falta por hacer está en [ROADMAP.md](ROADMAP.md).

## 1. Qué es

**Bookly** es una app móvil (Flutter) para encontrar y reservar servicios de belleza y
bienestar (barberías, estéticas, spas, uñas y otros) pagando un **anticipo del 25 %** en línea.

- Autora: Evelyn Jazmín Aguilar Salinas (Ingeniería de Software, Facultad de Informática, UAQ).
- Nació como proyecto final de *Desarrollo de Aplicaciones Móviles* y se presenta en la feria
  **Proyéctate**. La meta es publicarla en **Google Play**, gratis y con anuncios.
- Idioma: **todo en español**: textos de la app, comentarios del código y mensajes de error.
  La autora no habla inglés.

### Dos interfaces en la misma cuenta
- **Cliente**:
  - Inicio con *Cerca de ti*: un mapa con su ubicación en vivo y los negocios cercanos.
  - Búsqueda y categorías.
  - Sitio de cada negocio, reservas, compra de productos.
  - Novedades: publicaciones de los últimos 8 días, agrupadas por negocio en carrusel.
  - Mis citas y Billetera.
- **Negocio**: Agenda, Mi sitio (diseño de su página), Inventario (servicios y productos
  con clasificación), Publicaciones (foto o video) y Cuenta (datos, Cobros y ventas con
  Stripe Connect).
- Al registrarse se elige un perfil; se puede tener ambos y cambiar desde el perfil.

## 2. Tecnología

| Parte | Herramienta |
|---|---|
| App | Flutter 3.47 / Dart 3.13 (Android y web; iOS sin probar) |
| Inicio de sesión | Firebase Auth: Google **y** correo + contraseña (con verificación de correo) |
| Base de datos | Cloud Firestore |
| Archivos | Firebase Storage (solo videos de publicaciones) |
| Servidor | Cloud Functions v2, Node 22 (`functions/`) |
| Pagos | Stripe Checkout + Stripe Connect Express (modo prueba) |
| Correos | EmailJS (desde la app) |
| Mapas | flutter_map + teselas estándar de OpenStreetMap (definidas solo en `lib/config/map_config.dart`). Geocodificación: Nominatim |
| Ubicación | geolocator |
| Anuncios | google_mobile_ads (AdMob), solo Android/iOS |
| Video | video_player + visibility_detector |

- Proyecto de Firebase: **`bookly-c0692`**, en plan **Blaze**.
- Región de funciones: `us-central1`.
- Zona horaria de negocio: `America/Mexico_City`.

## 3. Estructura

```
lib/
  main.dart                 inicio, AuthGate (login → verificar correo → perfil → interfaz)
  firebase_options.dart     ⚠ generado por flutterfire, NO editar
  config/email_config.dart  ⚠ llaves de EmailJS de la autora, NO editar
  config/ads_config.dart    IDs de AdMob (ahora son los de PRUEBA)
  ads/                      ads.dart exporta ads_mobile.dart (AdMob) o ads_stub.dart (web)
  models/models.dart        UserProfile, Business, StaffMember, Item, Post, Appointment,
                            ShopOrder, Movement, PayoutStatus, SavedCard
  logic/schedule.dart       funciones puras: horarios, turnos, empalmes, openingStatus,
                            groupBySection
  logic/geo.dart            distancias (Haversine), nearestFirst
  services/                 database (Firestore), payments_service (llama funciones),
                            storage_service (videos), auth_service, email_service,
                            geocoding, location_service
  state/app_state.dart      AppSession (ChangeNotifier) + AppScope
  screens/                  pantallas de cliente; screens/business/ = panel del negocio
  widgets/                  piezas reutilizables (catalog_view, business_info_view,
                            nearby_section, video_post_player, location_map, post_card…)
  theme/app_colors.dart     paleta oficial
functions/
  index.js                  todas las Cloud Functions (reservas, pedidos, billetera,
                            Connect, webhook, página de regreso)
  schedule.js               la misma lógica de horarios, versión servidor
  test/schedule.test.js     pruebas (npm test)
test/widget_test.dart       pruebas de la lógica pura de la app (flutter test)
firestore.rules  storage.rules  firebase.json
README.md  FIREBASE_Y_CORREO.md  PAGOS_STRIPE.md  ANUNCIOS.md  ROADMAP.md
```

## 4. Reglas que NO se rompen

### Seguridad y dinero
1. **La app nunca escribe dinero ni citas.** Crear, cancelar o reprogramar citas, los pedidos,
   los movimientos, `busy` y `paymentStatus` los escribe **solo el servidor**. En
   `firestore.rules` tienen `allow write: if false`. Cualquier cambio de eso se hace en
   `functions/index.js` y se llama desde `lib/services/payments_service.dart`.
2. **El servidor calcula los montos** con el precio guardado en Firestore. Nunca se confía en
   un precio enviado por la app.
3. **La app nunca ve tarjetas.** Se capturan en Stripe Checkout; la app solo muestra la marca y
   los últimos 4 dígitos. Las llaves de Stripe están en Secret Manager
   (`STRIPE_SECRET_KEY` y `STRIPE_WEBHOOK_SECRET`); jamás van en el código.
4. Las reglas exigen **correo verificado** (`signedIn()` revisa `email_verified`).
5. **Privacidad:**
   - Los clientes ven horarios ocupados en `businesses/{id}/busy`, sin nombres ni correos.
   - La ubicación del usuario **no se guarda** en ningún lado.
6. **Otras protecciones del servidor:**
   - El webhook verifica la firma y procesa cada evento una sola vez (`stripeEvents`).
   - Hay límite de intentos por usuario (`rateLimits`).
   - Todas las funciones callable pasan por `safe()`, que convierte los errores de Stripe en
     mensajes claros en español.
7. **Modo prueba:** si el negocio no tiene Connect activo y la llave es `sk_test_`, el cobro va
   a la cuenta de Bookly (`transferFor` regresa vacío). En modo real eso se rechaza.
8. Los negocios de ejemplo (`demo_N` con `demo: true`) se reservan sin cobro. Un negocio real
   no puede marcarse como demo (lo impiden las reglas).

### Estilo y diseño
- **Paleta** (`AppColors`): `#1E5E6B` principal (teal) · `#28588B` botones (blue/action) ·
  `#64ABB0` aqua · `#ADDCEE` sky · `#DDF5FB` mist. El verde y el rojo son solo para estados.
- **Pantallas a todo el ancho.** Solo las fotos y videos de las publicaciones tienen tamaño
  máximo (480 px, como Instagram) y van **alineados a la izquierda**, no centrados.
- **Fotos y videos sin franjas:** respetan su forma entre 4:5 y 1.91:1 (`AdaptiveImage`). En
  tarjetas de tamaño fijo se usa `FramedImage`, que muestra la foto completa sobre la misma foto
  desenfocada.
- **Catálogo:** si el negocio clasificó sus servicios, se ven carruseles por clasificación con
  filtros arriba; si no, una cuadrícula. En cada tarjeta: nombre y precio arriba, imagen,
  botón Reservar abajo.
- **Videos:** se reproducen solos y en silencio cuando están en pantalla y se pausan al salir.
- Las imágenes (productos, logo, portada, galería, fotos de publicaciones) se guardan en
  **base64 dentro de Firestore**, comprimidas (máx. ~600 KB). Solo los videos van a Storage.
- Íconos: verificar que existan en `Icons` de Flutter 3.47 antes de usarlos.
- Usar `initialValue` (no `value`) en `DropdownButtonFormField`, y `activeThumbColor` en `Switch`.
- `latlong2` choca con `Path` de Flutter: importar siempre
  `import 'package:latlong2/latlong.dart' show LatLng;`.
- En PowerShell, las listas con coma van entre comillas: `--only "storage,firestore:rules"`.

## 5. Comandos

```powershell
cd C:\Users\Jazmin\ProyectoFina\bookly_app
flutter pub get
flutter test                                   # pruebas de la app
flutter run -d chrome                          # web (Chrome limpio, sin cuentas guardadas)
flutter run -d web-server --web-port 8080      # abrir http://localhost:8080 en tu Chrome
cd functions; npm install; npm test; cd ..     # pruebas del servidor
firebase deploy --only functions --project bookly-c0692
firebase deploy --only "storage,firestore:rules" --project bookly-c0692
firebase functions:log --project bookly-c0692
```

- Después de cambiar `functions/` hay que volver a publicar las funciones.
- Después de cambiar `firestore.rules` o `storage.rules` hay que publicar las reglas.

## 6. Datos en Firestore

```
users/{uid}                       name, email, isClient, isBusiness, mode
users/{uid}/movements             pagos/reembolsos del cliente (servidor)
businesses/{uid}                  datos + diseño del sitio + lat/lng + staff[]
businesses/{uid}/items            servicios y productos (section = clasificación)
businesses/{uid}/gallery          fotos del sitio
businesses/{uid}/busy/{apptId}    horarios ocupados sin datos personales (servidor)
businesses/{uid}/movements        ingresos y comisiones (servidor)
posts/{id}                        publicaciones (imageBase64 o videoUrl/videoPath)
appointments/{id}                 citas (servidor). Estados: pendiente_pago, confirmada,
                                  cancelada, expirada, reembolsada
orders/{id}                       compras de productos (servidor)
paymentStatus/{uid}               si el negocio ya cobra en línea (servidor, lectura pública)
stripeCustomers / stripeAccounts / stripeEvents / rateLimits   privadas, solo servidor
Storage: posts/{uid}/{timestamp}.mp4   videos (máx. 50 MB, solo el dueño sube)
```

## 7. Cómo trabajar con la autora

- Explicar paso a paso, en español sencillo y con los comandos exactos para PowerShell
  en Windows.
- Ella prueba en su laptop (`C:\Users\Jazmin\ProyectoFina\bookly_app`) y manda capturas.
- Hacer cambios pequeños y revisables; no rehacer pantallas que no pidió cambiar.
- Si algo no se pudo probar (por ejemplo, compilar Flutter), decirlo claramente.
