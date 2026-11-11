# Pagos con Stripe (modo prueba) – Billetera de Bookly

Con esto Bookly cobra de verdad (pero con dinero de prueba):

- **Cliente:** paga el anticipo del 25 % o compra productos, guarda y quita tarjetas
  (Perfil → **Billetera**).
- **Negocio:** conecta su cuenta de Stripe y recibe ahí los anticipos y las ventas,
  menos la comisión de Bookly del 5 % (Cuenta → **Cobros y ventas**).

> Todo es **modo prueba**: no se mueve dinero real y no se piden datos bancarios reales.

---

## Cómo está protegido (para explicarlo en clase)

| Riesgo | Cómo se evita |
|---|---|
| Robar números de tarjeta | La app **nunca** ve la tarjeta. Se escribe en la página de Stripe (certificada PCI). Bookly solo recibe marca y últimos 4 dígitos. |
| Modificar la app para pagar menos | El **servidor** calcula el monto con el precio guardado en la base de datos. Lo que mande la app se ignora. |
| Marcar una cita como "pagada" sin pagar | Las reglas de Firestore **prohíben** que la app escriba citas, pedidos o movimientos. Solo el servidor lo hace, y solo cuando Stripe le avisa (webhook **con firma verificada**). |
| Avisos falsos de Stripe | El webhook revisa la firma con un secreto; si no coincide, lo rechaza. |
| Avisos repetidos | Cada evento de Stripe se procesa una sola vez (`stripeEvents`). |
| Reservar el mismo horario dos veces | El servidor revisa el horario dentro de una **transacción** y lo aparta 30 min mientras se paga. |
| Pagar tarde o un monto distinto | El servidor lo detecta y **reembolsa automáticamente**. |
| Ver datos de otros clientes | La disponibilidad se lee de `busy`, que no tiene nombres, correos ni teléfonos. |
| Borrar tarjetas ajenas / cancelar citas ajenas | El servidor revisa que la tarjeta o cita sea tuya. |
| Ataques de fuerza bruta | Límite de intentos por minuto por usuario. |
| Llave secreta de Stripe en la app | La llave vive en **Secret Manager** de Google; nunca está en el código ni en la app. |
| Abrir páginas falsas | La app solo abre direcciones `https://*.stripe.com`. |

---

## Paso 1. Activar el plan Blaze en Firebase

Las funciones del servidor (Cloud Functions) necesitan el plan Blaze. Para un proyecto
escolar **no cuesta nada** (la capa gratuita es muy grande), pero pide una tarjeta.

1. Firebase Console → proyecto **bookly-c0692** → abajo a la izquierda **Actualizar** → **Blaze**.
2. Crea una **alerta de presupuesto** de, por ejemplo, $20 MXN para que te avise si algo raro pasa.

## Paso 2. Crear la cuenta de Stripe (modo prueba)

1. Entra a <https://dashboard.stripe.com/register> y crea la cuenta (país: **México**).
2. No hace falta activar la cuenta: arriba a la derecha deja encendido **Modo de prueba / Test mode**.
3. **Connect:** menú *Connect* → **Comenzar** → elige que eres una **plataforma** y completa el
   "perfil de la plataforma" (en modo prueba puedes poner datos de ejemplo). Sin esto, el botón
   "Conectar con Stripe" de los negocios da error.
4. Menú **Desarrolladores → Claves de API**: copia la **Clave secreta** (empieza con `sk_test_`).
   ⚠️ Nunca la pegues en la app ni la subas a GitHub.

## Paso 3. Instalar las dependencias del servidor

En PowerShell, dentro de la carpeta del proyecto:

```powershell
cd C:\Users\Jazmin\ProyectoFina\bookly_app\functions
npm install
npm test
cd ..
```

`npm test` corre las pruebas de horarios del servidor (deben salir todas en verde).

## Paso 4. Guardar la llave secreta en Secret Manager

```powershell
firebase functions:secrets:set STRIPE_SECRET_KEY --project bookly-c0692
```

Pega la clave `sk_test_...` cuando la pida (no se ve mientras escribes; es normal).

Por ahora guarda un valor temporal para el secreto del webhook (lo cambias en el paso 6):

```powershell
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET --project bookly-c0692
```

Escribe `pendiente` y Enter.

## Paso 5. Publicar el servidor y las reglas

```powershell
firebase deploy --only functions,firestore:rules --project bookly-c0692
```

La primera vez tarda varios minutos y puede preguntar si activa algunas APIs de Google: responde **Y**.
Al final verás la lista de funciones (`startBooking`, `stripeWebhook`, etc.).

> Las reglas nuevas **bloquean** que la app escriba citas directamente. Por eso este paso va
> junto con la app nueva: la versión anterior de la app ya no podrá agendar.

## Paso 6. Conectar el webhook de Stripe

El webhook es como Stripe le avisa al servidor "ya pagaron".

1. Stripe → **Desarrolladores → Webhooks → Agregar destino / Add endpoint**.
2. URL:
   ```
   https://us-central1-bookly-c0692.cloudfunctions.net/stripeWebhook
   ```
3. Eventos: `checkout.session.completed` y `checkout.session.expired`.
4. Marca también **"Eventos de cuentas conectadas"** si te lo pregunta (opcional).
5. Guarda y copia el **Secreto de firma** (empieza con `whsec_`).
6. Guárdalo y vuelve a publicar:
   ```powershell
   firebase functions:secrets:set STRIPE_WEBHOOK_SECRET --project bookly-c0692
   firebase deploy --only functions --project bookly-c0692
   ```

## Paso 7. Actualizar la app

```powershell
cd C:\Users\Jazmin\ProyectoFina\bookly_app
flutter pub get
flutter test
flutter run -d chrome
```

## Paso 8. Prueba completa (para tus capturas)

**Como negocio**

1. Cuenta → **Cobros y ventas** → **Conectar con Stripe**.
2. Se abre Stripe. En modo prueba usa datos de ejemplo:
   teléfono `000 000 0000`, código SMS `000000`, CLABE de prueba `000000001234567897`,
   y cualquier dato que te pida (Stripe muestra botones de "usar datos de prueba").
3. Regresa a la app y toca **Actualizar estado** → debe decir **Cobros activos**.
4. En **Inventario** agrega un servicio y un producto con existencias.

**Como cliente** (puede ser otra cuenta de Gmail, o la misma cambiando de interfaz)

1. Perfil → **Billetera** → **Agregar forma de pago** → tarjeta `4242 4242 4242 4242`,
   fecha futura (ej. `12/34`), CVV `123`. Regresa y toca **Actualizar**.
2. Entra a tu negocio → **Reservar** → elige horario → **Pagar con Stripe**.
3. Paga con la tarjeta guardada. La pantalla de la app cambia sola a **¡Cita confirmada!**
4. Revisa: *Mis citas* (cliente), *Agenda* y *Cobros y ventas* (negocio: cobrado, comisión, para ti).
5. Cancela la cita (con más de 24 h) → se reembolsa y aparece en Movimientos.
6. Compra un producto → baja la existencia y aparece en *Ventas de productos*.

Tarjetas de prueba útiles:

| Tarjeta | Resultado |
|---|---|
| 4242 4242 4242 4242 | Pago aprobado |
| 4000 0000 0000 0002 | Rechazada |
| 4000 0025 0000 3155 | Pide autenticación 3D Secure |

Los negocios de ejemplo (demo) se pueden reservar **sin cobro**, para probar sin Stripe.

---

## Problemas comunes

| Mensaje | Causa | Solución |
|---|---|---|
| "El servidor de pagos todavía no está instalado" | No se publicaron las funciones | Paso 5 |
| "Este negocio todavía no activa sus cobros en línea" | El negocio no terminó Stripe Connect | Paso 8 (negocio) y **Actualizar estado** |
| Se queda en "Esperando la confirmación del pago…" | Webhook mal configurado | Revisa la URL y el secreto `whsec_` (Paso 6). En Stripe → Webhooks verás si los avisos fallan |
| Error al conectar con Stripe | Falta el perfil de plataforma de Connect | Paso 2, punto 3 |
| "permission-denied" al agendar | App vieja con reglas nuevas | `flutter pub get` y vuelve a correr la app nueva |
| Las citas viejas no se ven ocupadas para otros clientes | Se crearon antes del servidor (no tienen registro en `busy`) | Son datos de prueba; el servidor de todas formas no deja reservar encima |

Para ver errores del servidor: `firebase functions:log --project bookly-c0692`.

## Nota: cuentas de negocio v2, sin panel Express

Stripe rechaza las cuentas Express cuando la plataforma tiene a Stripe como responsable de
pérdidas. Por eso `connectOnboarding` crea la cuenta con la **API v2** (`stripe.v2.core.accounts`,
`dashboard: none`, capacidades `card_payments` y `stripe_balance.stripe_transfers`) y el registro
se hace con `v2.core.accountLinks` (`account_onboarding`). `connectRefreshStatus` lee la cuenta
con `include` de `configuration.merchant` y `configuration.recipient`. Los cobros siguen siendo
destination charges con el id `acct_...`. Ya no existe el panel Express: la función
`connectDashboard` solo responde un aviso y el botón se quitó de la app; el negocio consulta sus
cobros en *Cobros y ventas*. Si Stripe dice "signed up for Connect", activa Connect en
Dashboard → Connect → Empezar. Una cuenta Express creada antes debe borrarse de
`stripeAccounts/{uid}` para crear una v2 nueva.

## Estado de cobro automático (webhook de Connect) — PENDIENTE DE VERIFICAR

Antes, `stripeAccounts/{uid}.chargesEnabled` y `paymentStatus/{uid}` solo cambiaban cuando el dueño
tocaba "Actualizar estado". Con dinero real, si Stripe desactivara los cobros de un negocio,
Bookly seguiría intentando cobrar. La función `stripeConnectWebhook` (separada de `stripeWebhook`)
recibe los avisos "thin" (v2) de Stripe, verifica la firma con `stripe.parseEventNotification`,
procesa cada aviso una sola vez (`stripeEvents`), busca el negocio por `accountId`, vuelve a leer
la cuenta v2 y guarda el estado igual que `connectRefreshStatus`.

Avisos que atiende (lógica en `functions/connect_events.js`):
- `v2.core.account[configuration.merchant].capability_status_updated`
- `v2.core.account[configuration.recipient].capability_status_updated`

**Qué falta verificar** (la documentación y los tipos del SDK lo respaldan, pero nunca se probó
con un aviso real): que Stripe mande el id de la cuenta en `related_object.id`, y el alcance del
destino ("Tu cuenta" vs "Cuentas conectadas"; según la guía de migración a Accounts v2, los eventos
v2 de cuentas conectadas usan el alcance **Tu cuenta**, pero otra guía dice **Cuentas conectadas**;
si no llegan avisos, prueba con el otro).

### Pasos manuales (sandbox)
1. Guarda el secreto (te pedirá el valor `whsec_...` que Stripe te da en el paso 6):
   ```powershell
   firebase functions:secrets:set STRIPE_CONNECT_WEBHOOK_SECRET --project bookly-c0692
   ```
   Para poder publicar, el secreto debe existir antes del deploy. Si aún no tienes el
   `whsec_`, guarda uno temporal y reemplázalo después.
2. Publica solo esa función (pedirá confirmar el secreto nuevo):
   ```powershell
   firebase deploy --only functions:stripeConnectWebhook --project bookly-c0692
   ```
   Copia su URL (`https://stripeconnectwebhook-...run.app`). Como `connectRefreshStatus` cambió,
   publica también `functions:connectRefreshStatus`.
3. Stripe Dashboard (sandbox) → Developers → Workbench → Webhooks → **Create new destination**.
4. Events from: **Your account** (si no llegan avisos, prueba **Connected accounts**).
5. Show advanced options → Payload style: **Thin**. Eventos: los dos de arriba.
6. Tipo de destino: Webhook endpoint, pega la URL del paso 2. Copia el *Signing secret* (`whsec_...`)
   y guárdalo con el comando del paso 1 (otro valor distinto al de `STRIPE_WEBHOOK_SECRET`).
7. Vuelve a publicar `functions:stripeConnectWebhook` para que tome el secreto nuevo.
8. Prueba: cambia una capacidad de una cuenta de prueba y revisa
   `firebase functions:log --project bookly-c0692`, y que `paymentStatus/{uid}` cambie.
