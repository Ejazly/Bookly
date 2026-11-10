# Bookly – App en Flutter (versión 0.4)

Bookly reúne negocios de servicios como barberías, estéticas, spas y uñas. Tiene **dos interfaces** en la misma app:

| Interfaz | Para quién | Qué puede hacer |
|---|---|---|
| **Cliente** | Quien busca un servicio | Explorar negocios, ver servicios, productos y publicaciones, agendar pagando un anticipo del 25 %, ver, cancelar o reprogramar sus citas |
| **Negocio** | Quien ofrece servicios | Tres apartados: **Agenda** (reservas con anticipo y personas agregadas por el negocio), **Mi sitio** (decorar su página: portada, logo, color, eslogan, descripción, redes, galería y publicaciones) e **Inventario** (productos y servicios con precio, descripción, imagen y existencias). Además, **Cuenta** para cambiar de interfaz |

- Al registrarse, cada persona elige si es **Cliente, Negocio o las dos**.
- Si tiene las dos, cambia de interfaz desde su perfil.
- **Billetera con Stripe (modo prueba):** el cliente guarda tarjetas y paga anticipos o productos; el negocio conecta su cuenta de Stripe y recibe el dinero menos la comisión de Bookly (5 %). Ver **[PAGOS_STRIPE.md](PAGOS_STRIPE.md)**.
- **Publicaciones con foto o video** (los videos se guardan en Firebase Storage).
- **Pestaña Información** en el sitio de cada negocio: mapa con su ubicación, botón *Cómo llegar*, si está abierto, horario de la semana, quién atiende y contacto.
- **Cerca de ti** en el inicio del cliente: mapa con tu ubicación en vivo y los negocios más cercanos (con distancia y si están abiertos). La ubicación nunca se guarda.
- **Servicios en carrusel** con imagen grande, agrupados por la clasificación que elige el negocio (Cortes, Barba, Masajes…).
- Paleta de colores: `#1E5E6B` `#28588B` `#64ABB0` `#ADDCEE` `#DDF5FB`.
- La cuenta siempre está **vinculada con Google (Gmail)**. A ese correo llegan los avisos: el negocio recibe un correo cada vez que un cliente agenda, cancela o cambia una cita.

## Cómo correrla

1. Configura Firebase y EmailJS siguiendo **[FIREBASE_Y_CORREO.md](FIREBASE_Y_CORREO.md)** (una sola vez, ~30 min).
   Después, el servidor de pagos con **[PAGOS_STRIPE.md](PAGOS_STRIPE.md)**.
2. En la terminal:
   ```
   flutter pub get
   flutter run -d chrome
   ```
3. Pruebas automáticas:
   ```
   flutter test
   ```

## Estructura del código

```
lib/
  main.dart                     ← inicia Firebase y AuthGate (decide qué pantalla mostrar)
  firebase_options.dart         ← datos de tu proyecto de Firebase (los pegas tú)
  config/email_config.dart      ← datos de EmailJS (los pegas tú)
  models/models.dart            ← UserProfile, Business, Item, Post, Appointment
  logic/schedule.dart           ← lógica de la agenda (horarios, choques, reembolsos)
  services/
    auth_service.dart           ← inicio de sesión con Google
    database.dart               ← todo lo que se lee y escribe en Firestore
    email_service.dart          ← correos de aviso por EmailJS
    payments_service.dart       ← llamadas al servidor de pagos (Stripe)
  state/app_state.dart          ← sesión: usuario, perfil, negocio e interfaz actual
  data/sample_data.dart         ← negocios de ejemplo que se cargan la primera vez
  widgets/                      ← piezas reutilizables (tarjetas, imágenes, días, horarios, encabezado del sitio)
  screens/
    login_screen.dart           ← entrar con Google
    register_screen.dart        ← "¿Cómo usarás Bookly?" (Cliente / Negocio / ambos)
    business_setup_screen.dart  ← alta y edición de los datos del negocio
    home_shell.dart             ← INTERFAZ CLIENTE: Inicio, Novedades, Mis citas, Perfil
    home_screen.dart  feed_screen.dart  business_screen.dart
    booking_screen.dart  payment_screen.dart  appointments_screen.dart  profile_screen.dart
    order_screen.dart           ← comprar un producto
    checkout_wait_screen.dart   ← espera la confirmación del pago de Stripe
    wallet_screen.dart          ← Billetera: tarjetas, movimientos y compras
    business_panel_screen.dart  ← INTERFAZ NEGOCIO: Agenda, Mi sitio, Inventario, Cuenta
    business/
      agenda_screen.dart        ← citas por día o próximas; filtros con anticipo / agregadas por mí
      add_client_screen.dart    ← el negocio agrega una persona (con o sin anticipo)
      site_editor_screen.dart   ← "Mi sitio": portada, logo, color, textos, redes, galería
      inventory_screen.dart     ← lista del inventario, existencias +/−, visible u oculto
      item_form_screen.dart     ← nuevo producto / editar (precio, descripción, imagen)
      posts_screen.dart  post_form_screen.dart  ← publicaciones
      business_profile_screen.dart  ← "Cuenta": datos del negocio y cambio de interfaz
      payouts_screen.dart       ← "Cobros y ventas": conectar Stripe, ingresos y comisión
test/widget_test.dart           ← pruebas de la lógica
functions/                      ← SERVIDOR (Cloud Functions, Node 22)
  index.js                      ← reservas, pedidos, billetera, cobros y webhook de Stripe
  schedule.js                   ← la misma lógica de horarios, pero la que manda
  test/schedule.test.js         ← pruebas del servidor (npm test)
firestore.rules                 ← reglas de seguridad (citas y pagos solo los escribe el servidor)
```

`lib/screens/videos_screen.dart` ya no se usa. Fue reemplazado por "Novedades" y puedes borrarlo.

## Cómo fluye la app

```
Sin sesión ──► LoginScreen (Google)
                  │
       ¿tiene perfil en users/{uid}?
          no ──► RoleSelectionScreen (Cliente / Negocio / ambos)
          sí ──► según profile.mode:
                   client   ──► HomeShell (interfaz cliente)
                   business ──► ¿existe businesses/{uid}?
                                  no ──► BusinessSetupScreen
                                  sí ──► BusinessShell (interfaz negocio)
```

`AuthGate` (en `main.dart`) escucha la sesión y cambia la pantalla sola. Por ejemplo, al tocar **"Cambiar a interfaz de cliente"** solo se actualiza `mode` en Firestore, y la app cambia de interfaz inmediatamente.

## Datos en Firestore

| Colección | Contenido |
|---|---|
| `users/{uid}` | nombre, Gmail, `isClient`, `isBusiness`, `mode` |
| `businesses/{uid}` | datos generales (nombre, horario, días de descanso, personal, `ownerEmail`) y diseño del sitio (portada, logo, color, eslogan, descripción, redes) |
| `businesses/{uid}/gallery/{id}` | fotos de la galería del sitio |
| `businesses/{uid}/items/{id}` | inventario: `kind` (servicio/producto), nombre, descripción, precio, duración o existencias, imagen, visible |
| `posts/{id}` | publicaciones: negocio, texto, imagen, fecha |
| `appointments/{id}` | citas: negocio, servicio, profesional, inicio, `day`, cliente (nombre, Gmail, teléfono), anticipo, estado (`pendiente_pago`, `confirmada`, `cancelada`, `expirada`, `reembolsada`), si la agregó el negocio. **Solo las escribe el servidor** |
| `businesses/{uid}/busy/{id}` | horarios ocupados sin datos personales (para mostrar disponibilidad) |
| `orders/{id}` | compras de productos |
| `users/{uid}/movements`, `businesses/{uid}/movements` | pagos, ventas, comisiones y reembolsos |
| `paymentStatus/{uid}` | si el negocio ya puede cobrar en línea |
| `stripeCustomers`, `stripeAccounts`, `stripeEvents`, `rateLimits` | privados: solo el servidor |

## Lógica de la agenda (`lib/logic/schedule.dart`)

1. **Horarios:** desde la hora de apertura, cada 60 min, solo si *inicio + duración ≤ cierre*. El negocio no ofrece horarios los días que cierra.
2. **Choques:** dos citas se empalman si `inicioA < finB` y `inicioB < finA`. Solo se comparan citas del mismo profesional y se ignoran las canceladas.
3. **Profesional:** si el cliente elige "Cualquiera", se asigna el primero que esté libre.
4. **Antes de cobrar**, el servidor (`functions/schedule.js`) revisa otra vez el horario dentro de una transacción y lo aparta 30 minutos mientras se paga. Si el pago no llega, el horario se libera solo.
5. **Cancelación:** con 24 h o más de anticipación el anticipo es reembolsable.

## Pendientes para la siguiente entrega

- Pasar Stripe de modo prueba a modo real (requiere activar la cuenta).
- Activar App Check para que solo la app oficial pueda llamar al servidor.
- Notificaciones push en el celular (Firebase Cloud Messaging).
- Configurar Android con `flutterfire configure`.
- Reseñas y calificaciones reales.
