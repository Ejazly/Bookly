# Configurar Firebase y los correos de Bookly

Esta guía conecta Bookly con:

- **Firebase Authentication** para entrar con tu cuenta de Google (Gmail).
- **Cloud Firestore**, la base de datos en la nube donde se guardan usuarios, negocios, inventario, publicaciones y citas.
- **EmailJS**, un servicio gratuito que envía desde un Gmail los correos de aviso. Por ejemplo, avisa al negocio cuando un cliente agenda.

Todo es gratis y no pide tarjeta. Calcula unos 30 minutos.

> Mientras no termines estos pasos, la app abre una pantalla que dice **"Falta conectar Firebase"**. Es normal.

---

## Paso 1. Descargar los paquetes nuevos

En la terminal, dentro de la carpeta del proyecto:

```
flutter pub get
```

Esto descarga `firebase_core`, `firebase_auth`, `cloud_firestore`, `image_picker` (para elegir fotos) y `http` (para enviar los correos). Ya están escritos en `pubspec.yaml`.

---

## Paso 2. Crear el proyecto de Firebase

1. Entra a **console.firebase.google.com** con tu cuenta de Google.
2. Haz clic en **Crear un proyecto** (o "Agregar proyecto").
3. Nombre: `bookly` (Firebase le agrega letras al final, no importa).
4. Google Analytics: puedes **desactivarlo**; no se usa.
5. Clic en **Crear proyecto** y espera a que termine.

---

## Paso 3. Registrar la app web y copiar sus datos

1. En la página principal del proyecto, haz clic en el ícono **`</>`** (Web).
2. Apodo de la app: `bookly-web`. **No** marques "Firebase Hosting".
3. Clic en **Registrar app**.
4. Aparece un bloque de código parecido a este:

   ```js
   const firebaseConfig = {
     apiKey: "AIzaSy...",
     authDomain: "bookly-1a2b3.firebaseapp.com",
     projectId: "bookly-1a2b3",
     storageBucket: "bookly-1a2b3.firebasestorage.app",
     messagingSenderId: "1234567890",
     appId: "1:1234567890:web:abc123..."
   };
   ```

5. Abre `lib/firebase_options.dart` y, en la parte de `web`, cambia cada `PEGA_AQUI_...` por el valor correspondiente **entre comillas simples**:

   ```dart
   static const FirebaseOptions web = FirebaseOptions(
     apiKey: 'AIzaSy...',
     appId: '1:1234567890:web:abc123...',
     messagingSenderId: '1234567890',
     projectId: 'bookly-1a2b3',
     authDomain: 'bookly-1a2b3.firebaseapp.com',
     storageBucket: 'bookly-1a2b3.firebasestorage.app',
   );
   ```

   La parte de `android` se puede quedar así por ahora: solo se usa si corres la app en un celular Android.

> Si después pierdes estos datos, están en ⚙ **Configuración del proyecto → General → Tus apps → bookly-web → Configuración del SDK → Config**.

---

## Paso 4. Activar el inicio de sesión con Google

1. En el menú izquierdo: **Compilación (Build) → Authentication → Comenzar**.
2. Pestaña **Sign-in method** → **Google** → activa el interruptor **Habilitar**.
3. En "Correo electrónico de asistencia del proyecto" elige tu Gmail.
4. **Guardar**.

En la pestaña **Settings → Authorized domains** ya debe aparecer `localhost`. Ese es el dominio que usa Chrome cuando corres `flutter run -d chrome`.

---

## Paso 5. Crear la base de datos Firestore y sus reglas

1. Menú izquierdo: **Compilación → Firestore Database → Crear base de datos**.
2. Ubicación: elige la que aparezca por defecto o una de Estados Unidos (por ejemplo `nam5`). **No se puede cambiar después.**
3. Elige **Comenzar en modo de producción** → **Crear**.
4. Ve a la pestaña **Reglas**, borra lo que tenga y pega todo el contenido del archivo `firestore.rules` del proyecto.
5. Clic en **Publicar**.

Las reglas hacen que:

- cada persona solo pueda leer y editar su propio perfil;
- solo el dueño de un negocio pueda cambiar sus datos, el diseño de su sitio, su galería de fotos, su inventario y sus publicaciones;
- cualquier usuario con sesión pueda crear una cita y ver qué horarios están ocupados;
- solo el cliente de una cita, o el negocio, puedan cancelarla o cambiarla.

---

## Paso 6. Configurar los correos con EmailJS

Firebase no envía correos por sí solo sin pagar. EmailJS tiene un plan gratuito de 200 correos al mes y los manda desde un Gmail que tú conectas.

**Recomendación:** crea un Gmail solo para la app, por ejemplo `bookly.avisos@gmail.com`. Los correos saldrán de esa cuenta y llegarán al Gmail de cada negocio o cliente.

### 6.1 Crear la cuenta y conectar Gmail

1. Entra a **emailjs.com** → **Sign Up** (gratis).
2. Menú **Email Services → Add New Service → Gmail**.
3. Clic en **Connect Account** y elige el Gmail que enviará los avisos. Acepta los permisos.
4. **Create Service**. Copia el **Service ID** (algo como `service_ab12cd3`).

### 6.2 Crear la plantilla del correo

1. Menú **Email Templates → Create New Template**.
2. En **Subject** escribe exactamente:

   ```
   {{subject}}
   ```

3. En el contenido del correo escribe:

   ```
   Hola {{to_name}},

   {{message}}

   — Bookly
   ```

4. En el panel de la derecha:
   - **To Email:** `{{to_email}}`
   - **From Name:** `Bookly`
5. **Save**. Copia el **Template ID** (algo como `template_xy98zw7`).

Las palabras entre llaves `{{ }}` son variables. La app les manda el valor en cada correo. Por eso una sola plantilla sirve para todos los avisos: nueva cita, cancelación, cambio de horario y cliente agregado por el negocio.

### 6.3 Copiar la llave pública

1. Menú **Account → General**.
2. Copia la **Public Key**.

### 6.4 Pegar los datos en la app

Abre `lib/config/email_config.dart` y reemplaza los tres `PEGA_AQUI_...`:

```dart
static const String serviceId = 'service_ab12cd3';
static const String templateId = 'template_xy98zw7';
static const String publicKey = 'TuPublicKey123';
```

> Si algún día corres la app en Android, en EmailJS ve a **Account → Security** y activa **"Allow EmailJS API for non-browser applications"**. En Chrome no hace falta.

---

## Paso 7. Correr la app

```
flutter pub get
flutter run -d chrome
```

Al tocar **Continuar con Google** se abre una ventana emergente. Si Chrome la bloquea, permite las ventanas emergentes para `localhost` (aparece un ícono en la barra de direcciones).

La primera vez que alguien entra, la app guarda **3 negocios de ejemplo** (Barbería El Clásico, Estética Bella Luna y Spa Lirio) para que la sección de Inicio no se vea vacía. Esos negocios no tienen dueño, así que sus citas **no envían correo**.

---

## Paso 8. Prueba completa (para tus capturas)

1. **Registro.** Entra con tu Gmail. En "¿Cómo usarás Bookly?" elige **Cliente y Negocio** → Continuar.
2. **Registrar negocio (paso 1 de 2).** Llena nombre, categoría, dirección, horario, días de descanso y personal (por ejemplo `Jazmín, Ana`) → **Crear mi negocio**.
3. **Decorar el sitio (paso 2 de 2).** La app abre el apartado **Mi sitio**: sube portada y logo, elige un color, escribe un eslogan y la descripción, agrega WhatsApp o Instagram → **Guardar cambios del sitio**. Agrega fotos a la galería. Toca **Ver como cliente** para ver cómo queda.
4. **Inventario.** Pestaña **Inventario → Nuevo producto**:
   - Crea un **Servicio** (ej. "Manicure", 45 min, $200) con una foto.
   - Crea un **Producto** (ej. "Esmalte rojo", $80, 5 piezas) con una foto.
   - Edita uno: cambia el precio, la descripción o la imagen. Usa los botones **+ / −** para las existencias.
5. **Publicación.** En **Mi sitio → Publicaciones → Nueva publicación** con foto y texto.
6. **Cambiar de interfaz.** Pestaña **Cuenta → Cambiar a interfaz de cliente**.
7. **Agendar como cliente.** En Inicio busca tu negocio (ya se ve con tu logo y eslogan) → Reservar el servicio → elige día y hora → paga con la tarjeta de prueba `4242 4242 4242 4242`, fecha `12/28` y CVV `123`.
8. **Revisa tu Gmail.** Debe llegar el correo **"Nueva cita: …"** con los datos del cliente, el horario y el anticipo.
9. **Agenda del negocio.** Desde Perfil → **Ir a mi negocio**. En **Agenda** aparece la cita con las etiquetas "Reservó en la app" y "Anticipo $…". Prueba la vista **Próximas** y los filtros **Reservas con anticipo / Agregadas por mí**.
10. **Agregar persona a mano.** En Agenda → **Agregar persona**: nombre, correo (puede ser el de un compañero), servicio, profesional, día, hora y si dejó **anticipo** (sin anticipo, 25 % u otro monto) → **Agregar a la agenda**. A ese correo le llega la confirmación. Si esa persona entra a Bookly con ese Gmail, verá la cita en "Mis citas".
11. **Cancelar o reprogramar** desde "Mis citas" (cliente): al negocio le llega un correo con el cambio.

---

## Problemas comunes

| Mensaje o síntoma | Causa | Solución |
|---|---|---|
| "Falta conectar Firebase" | Aún hay `PEGA_AQUI` en `firebase_options.dart` | Paso 3 |
| "El inicio de sesión con Google no está activado" | Google no está habilitado | Paso 4 |
| "Este dominio no está autorizado" | Falta `localhost` en Authorized domains | Authentication → Settings → Authorized domains → Add domain → `localhost` |
| La ventana de Google no aparece | Chrome bloqueó la ventana emergente | Permite ventanas emergentes para localhost |
| "permission-denied" o "No se pudo guardar tu perfil" | No se publicaron las reglas | Paso 5, punto 4 |
| "No se pudieron cargar los datos… requires an index" | Firestore pide un índice | Haz clic en el enlace del error, Firebase lo crea solo; espera 2 min |
| La cita se guarda, pero no llega el correo | EmailJS sin configurar o datos mal copiados | Paso 6; revisa también la carpeta de Spam |
| El aviso de correos dice "aún no están configurados" | Siguen los `PEGA_AQUI` en `email_config.dart` | Paso 6.4 |
| "La imagen es muy pesada" | La foto pesa demasiado aun comprimida | Usa una foto más pequeña o una captura |
| No se pueden subir fotos a la galería ("permission-denied") | Tienes las reglas viejas | Vuelve a copiar `firestore.rules` y publícalo (se agregó la parte de `gallery`) |

---

## Decisiones de diseño (por si te preguntan en clase)

- **¿Por qué solo Google y no correo/contraseña?** El requisito es que la cuenta esté vinculada a Gmail. Así el correo siempre es real y los avisos llegan, sin tener que verificar correos.
- **¿Por qué las imágenes están en Firestore y no en Firebase Storage?** Hoy Storage pide activar el plan de pago (con tarjeta). Las fotos se comprimen (máx. 900 px, calidad 70 %) y se guardan como texto base64 dentro del documento. Firestore permite hasta 1 MB por documento. Para una versión comercial convendría pasarlas a Storage.
- **¿Por qué EmailJS y no Cloud Functions?** Cloud Functions también requiere el plan de pago. EmailJS se llama directamente desde la app con una petición HTTP.
- **Una cuenta, dos interfaces.** El perfil (`users/{uid}`) guarda `isClient`, `isBusiness` y `mode` (la interfaz actual). El negocio se guarda con el mismo id que la cuenta (`businesses/{uid}`), por eso cada cuenta tiene un negocio.
- **Las citas se buscan por Gmail del cliente.** Gracias a eso, las citas que el negocio agrega a mano también aparecen en la app del cliente si escribe su Gmail.
- **Limitación conocida:** para calcular los horarios ocupados, cualquier usuario con sesión puede leer las citas, incluido el nombre del cliente. En producción se separaría en una colección solo con los horarios ocupados.
