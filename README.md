# Bookly – App en Flutter (versión 0.1)

Bookly es una app para encontrar negocios de servicios (barberías, estéticas, spas, uñas), ver sus servicios y **agendar una cita pagando un anticipo del 25 %**.

Esta primera versión incluye las 9 pantallas del diseño y la **agenda funcionando de verdad**: horarios ocupados, choques entre citas, anticipo, pago simulado, cancelación y reprogramación. Todavía **no usa Firebase**; los datos viven en memoria mientras la app está abierta. Esto es a propósito: así puedes correrla sin configurar nada extra y aprender Flutter paso a paso.

---

## 1. Instalar Flutter en Windows (una sola vez)

> Si algo de esta sección no coincide con lo que ves, la guía oficial está en **docs.flutter.dev → Get started → Install → Windows**.

1. **Instala Git para Windows** (git-scm.com). Flutter lo necesita para actualizarse.
2. **Instala Visual Studio Code** y, dentro de VS Code, la extensión **Flutter** (de Dart Code). Esa extensión instala también la de Dart.
3. **Descarga el SDK de Flutter**. Tienes dos caminos:
   - **Desde VS Code (el más fácil):** abre la paleta de comandos con `Ctrl + Shift + P`, escribe `Flutter: New Project`. Si no encuentra Flutter, te ofrece **Download SDK**. Elige una carpeta sin espacios ni acentos, por ejemplo `C:\src\` o `C:\Users\TuUsuario\develop\`. Cuando termine, acepta **Add SDK to PATH**.
   - **Manual:** descarga el `.zip` del SDK desde la página oficial, descomprímelo en `C:\src\flutter` y agrega `C:\src\flutter\bin` a la variable de entorno **Path** (Inicio → "Editar las variables de entorno del sistema" → Variables de entorno → Path → Nuevo).
4. **Cierra y vuelve a abrir** la terminal (o VS Code) y ejecuta:
   ```
   flutter doctor
   ```
   Te dirá qué tienes listo. Para empezar **solo necesitas que aparezca Chrome** con palomita. Android Studio y Visual Studio son opcionales (los necesitarás después para probar en celular/emulador Android o como app de Windows).

## 2. Preparar y correr este proyecto

1. Descomprime `bookly_app.zip` en una carpeta sin espacios, por ejemplo `C:\proyectos\bookly_app`.
2. Abre esa carpeta en VS Code (**File → Open Folder**).
3. Abre una terminal en VS Code (`Ctrl + ñ` o **Terminal → New Terminal**) y ejecuta:
   ```
   flutter create . --project-name bookly
   ```
   Este comando **agrega las carpetas de cada plataforma** (`android`, `ios`, `web`, `windows`…). No borra el código que ya está en `lib/` ni en `test/`.
4. Descarga las dependencias:
   ```
   flutter pub get
   ```
5. Córrela en Chrome:
   ```
   flutter run -d chrome
   ```
   Tip: en Chrome presiona `F12` y activa la vista de celular (ícono de teléfono) para verla del tamaño de un móvil.
6. Mientras la app corre, si cambias código y guardas, presiona `r` en la terminal (**hot reload**) para ver el cambio sin reiniciar. `R` reinicia por completo y `q` sale.

Para correrla en un emulador Android: instala Android Studio, crea un dispositivo en **Device Manager**, ábrelo y ejecuta `flutter run` (te dejará elegir el emulador).

## 3. Cómo probar la agenda (recorrido para tu reporte)

1. **Inicio de sesión:** escribe cualquier correo válido y una contraseña de 6+ caracteres, o usa "Continuar con Google" (simulado).
2. **Inicio:** busca "corte" o filtra por categoría. Toca **Barbería El Clásico**.
3. **Perfil del negocio:** revisa las pestañas Servicios, Fotos, Videos y Reseñas. En **Corte + barba** toca **Reservar**.
4. **Agendar cita:**
   - Los domingos aparecen deshabilitados (el negocio no abre).
   - Los horarios **tachados** ya están ocupados por otros clientes o ya pasaron.
   - Si eliges un profesional (Luis o Andrés), los horarios se recalculan solo para él. "Cualquiera" toma al primero libre.
   - Abajo ves el anticipo: para $230 es **$57.50**.
5. **Pago del anticipo:** usa una tarjeta de prueba:
   | Tarjeta | Resultado |
   |---|---|
   | `4242 4242 4242 4242` | Pago aprobado → la cita se confirma |
   | `4000 0000 0000 0002` | Pago rechazado → la cita **no** se agenda |
   Fecha: cualquier fecha futura (ej. `12/28`). CVV: cualquier número de 3 dígitos.
6. **Mis citas:** después del pago la app te lleva aquí. La cita aparece como *Confirmada*.
   - **Reprogramar:** abre la agenda con la cita actual; elige otro horario y confirma (el anticipo se conserva).
   - **Cancelar:** si faltan más de 24 h te avisa que se reembolsa el anticipo; si faltan menos, que no es reembolsable. La cita pasa al *Historial*.
7. **Vuelve a agendar el mismo horario:** verás que ahora aparece tachado para ese profesional.
8. **Panel del negocio:** cierra sesión (Perfil → Cerrar sesión) y usa "Entrar como negocio (demo)". Ahí aparecen las citas del día, incluidas las que agendaste (marcadas como *Nueva*).

Toma capturas de cada paso: te sirven como evidencia de **pruebas funcionales** en el PDF de avance.

## 4. Pruebas automáticas

En la terminal:
```
flutter test
```
El archivo `test/widget_test.dart` revisa automáticamente:

| Prueba | Qué verifica |
|---|---|
| PF-08 | El anticipo de $230 es $57.50 y el restante $172.50; redondeo a centavos |
| Horarios | Se generan de la apertura al cierre según la duración; no hay horarios en día cerrado; no se reservan horas pasadas |
| PF-07 | Un horario se ocupa cuando todos los profesionales están ocupados; reservar dos veces lo mismo marca error; un servicio de 2 h bloquea las horas que se empalman |
| PF-10 | La cita pagada aparece en "Próximas" con el anticipo correcto |
| Cancelar / reprogramar | Cancelar libera el horario; regla de las 24 h; reprogramar mueve la cita y libera la hora anterior |
| Pantalla inicial | La app abre en Iniciar sesión |

Si todo sale bien verás `All tests passed!`. Una captura de esa salida también es buena evidencia para el reporte.

## 5. Estructura del código

```
lib/
  main.dart                  ← punto de entrada; crea el estado y el tema
  theme/
    app_colors.dart          ← paleta de colores de Bookly
    app_theme.dart           ← tema global de Material
  models/models.dart         ← clases: Service, Professional, Business, Appointment
  data/sample_data.dart      ← negocios de ejemplo (luego vendrán de Firestore)
  state/app_state.dart       ← LÓGICA DE LA AGENDA y lista de citas
  utils/format.dart          ← fechas, horas y dinero en español
  widgets/common.dart        ← piezas reutilizables (tarjetas, botones, diálogos)
  screens/
    login_screen.dart        ← 3.1 Inicio de sesión
    register_screen.dart     ← 3.2 Registro (Cliente / Negocio)
    home_shell.dart          ← barra inferior: Inicio, Videos, Mis citas, Perfil
    home_screen.dart         ← 3.3 Explorar negocios
    business_screen.dart     ← 3.4 Perfil del negocio
    videos_screen.dart       ← 3.5 Videos promocionales
    booking_screen.dart      ← 3.6 Agendar / reprogramar cita
    payment_screen.dart      ← 3.7 Pago del anticipo
    appointments_screen.dart ← 3.8 Mis citas
    business_panel_screen.dart ← 3.9 Panel del negocio
    profile_screen.dart      ← Perfil del cliente
test/widget_test.dart        ← pruebas automáticas
assets/logo.png              ← logo de Bookly
```

## 6. Conceptos de Flutter que usa el proyecto

**Todo es un widget.** Un botón, un texto, un espacio, una pantalla completa: todo es un widget, y una pantalla es un árbol de widgets anidados. Por ejemplo, una tarjeta de servicio es un `AppCard` que contiene un `Row` (fila) con un `Column` (columna de textos), el precio y un botón.

**StatelessWidget vs. StatefulWidget.**
- `StatelessWidget` solo dibuja lo que recibe y no cambia por sí mismo (ej. `BusinessCard`).
- `StatefulWidget` guarda datos que cambian mientras la pantalla está abierta. Por ejemplo, en `BookingScreen` se guardan el día elegido (`_day`), el horario (`_time`) y el profesional (`_pro`). Cuando cambian se llama a `setState(() { ... })` y Flutter vuelve a ejecutar `build` para redibujar.

**Layouts básicos.**
- `Column` acomoda hacia abajo y `Row` hacia los lados.
- `Expanded` hace que un hijo ocupe el espacio que sobra en una fila o columna.
- `ListView` es una lista con scroll; `Wrap` acomoda elementos y los pasa a la siguiente línea si no caben (así se muestran los horarios).
- `Stack` encima un widget sobre otro (así se pone el botón de regresar sobre la portada).
- `Padding` y `SizedBox` dan espacios.

**Navegación.** Cada pantalla se abre con `Navigator.of(context).push(MaterialPageRoute(builder: (_) => OtraPantalla()))` y se cierra con `Navigator.pop(context)`. Después del pago se usa `popUntil((route) => route.isFirst)` para regresar hasta el inicio de un solo paso.

**Estado compartido.** Las citas deben verse en varias pantallas (Agendar, Mis citas, Panel del negocio). Por eso viven en una sola clase, `AppState`, que extiende `ChangeNotifier`. Esta clase se "comparte" con toda la app mediante `AppScope`, que es un `InheritedNotifier`:
- `AppScope.of(context)` se usa dentro de `build`. La pantalla queda "suscrita" y se redibuja sola cuando el estado llama a `notifyListeners()`.
- `AppScope.read(context)` se usa dentro de botones o funciones, cuando solo necesitas hacer una acción.

Cuando agregues Firebase, esta misma clase será la que lea y escriba en Firestore. Las pantallas casi no tendrán que cambiar.

**Formularios.** Los campos `TextFormField` dentro de un `Form` tienen un `validator` que regresa un mensaje de error o `null` si está bien. `_formKey.currentState!.validate()` revisa todos los campos al mismo tiempo. Así funcionan el inicio de sesión, el registro y el formulario de la tarjeta.

## 7. Cómo funciona la lógica de la agenda

Todo está en `lib/state/app_state.dart`:

1. **Generar horarios (`slotsFor`).** Empieza en la hora de apertura y avanza cada 60 minutos. Un horario solo se agrega si **inicio + duración del servicio ≤ hora de cierre**. Si el negocio cierra ese día de la semana, regresa una lista vacía.
2. **Detectar choques (`isProfessionalFree`).** Dos citas se empalman si `inicioA < finB` **y** `inicioB < finA`. Esta fórmula cubre todos los casos: una dentro de otra, que se crucen al inicio o al final. Solo se comparan citas del mismo negocio y del mismo profesional, y se ignoran las canceladas.
3. **Elegir profesional (`findProfessional`).** Si la usuaria eligió a alguien, solo se revisa a esa persona. Si eligió "Cualquiera", se prueba con cada profesional y se asigna el primero libre. Si el horario ya pasó, no se puede reservar.
4. **Reservar (`book`).** Vuelve a revisar que el horario siga libre, por si alguien lo tomó mientras pagabas. Luego crea la cita con el anticipo `depositFor(precio)` = precio × 0.25 redondeado a centavos.
5. **Cancelar (`cancel`) y reprogramar (`reschedule`).** Cancelar cambia el estado a *cancelada*, lo que libera el horario. Reprogramar busca disponibilidad ignorando la propia cita (para que no choque consigo misma) y cambia la fecha y el profesional.
6. **Datos de ejemplo (`_seedBookings`).** Al abrir la app se generan citas de "otros clientes" en los próximos 10 días para que haya horarios ocupados que probar.

## 8. Subir a GitHub (para la liga del repositorio)

1. Crea una cuenta en github.com si no tienes, y luego **New repository** → nombre `bookly` → **Public** → *sin* README (ya tienes uno) → **Create repository**.
2. En la terminal, dentro de la carpeta del proyecto:
   ```
   git init
   git add .
   git commit -m "Bookly v0.1: interfaces y agenda funcional"
   git branch -M main
   git remote add origin https://github.com/TU_USUARIO/bookly.git
   git push -u origin main
   ```
   (`flutter create .` ya generó un `.gitignore` que evita subir archivos pesados como `build/`.)
3. La liga para tu PDF es `https://github.com/TU_USUARIO/bookly`.

## 9. Qué sigue

- **Firebase:** agregar `firebase_core`, `firebase_auth` y `cloud_firestore` para tener usuarios y citas reales guardados en la nube. La clase `AppState` es el único lugar que tendría que hablar con Firestore.
- **Pagos reales en modo de prueba:** integrar Mercado Pago o Stripe. El botón "Pagar" ya está preparado: solo hay que cambiar el pago simulado por la llamada a la pasarela.
- **Videos reales:** paquete `video_player` y Firebase Storage.
- **Notificaciones:** recordatorio 2 h antes de la cita con Firebase Cloud Messaging.
- **Panel del negocio:** pantallas para editar servicios, horarios y promociones (hoy muestran "próximamente").
