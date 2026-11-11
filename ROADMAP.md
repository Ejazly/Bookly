# ROADMAP — Bookly

Estado del proyecto al **10 de noviembre de 2026**. El contexto técnico está en
[AGENTS.md](AGENTS.md).

Leyenda: ✅ terminado · 🟡 hecho pero falta probar o configurar · 🔴 atorado · ⬜ pendiente

---

## 🔴 Atorado (resolver primero)

| # | Qué | Por qué está atorado | Cómo se destraba |
|---|---|---|---|
| 1 | **Activar cobros del negocio (Stripe Connect)** | Primero salía "You can only create new accounts if you've signed up for Connect". Ya se activó Connect y se creó la cuenta del negocio, pero falta confirmar que diga **"Cobros activos"** | **Cambio:** Stripe rechazó cuentas Express (la plataforma tiene a Stripe como responsable de pérdidas), así que `connectOnboarding` ahora crea cuentas **v2 sin panel Express** (se quitó el botón del panel). Hay que publicar las funciones y reconectar con una cuenta nueva (la cuenta Express anterior ya no sirve; borrar `stripeAccounts/{uid}`). Cuenta → Cobros y ventas → *Actualizar estado*. Si falta, *Continuar en Stripe* con datos de prueba. Mientras tanto, en modo prueba se puede cobrar sin Connect. **Cómo probar:** ya no hace falta borrar `stripeAccounts/{uid}` (el registro viejo se migra solo); publicar funciones y tocar Cobros y ventas → *Continuar en Stripe*. **Pendiente con dinero real:** manejar el evento `account.updated` (hoy `chargesEnabled` solo se guarda al tocar *Actualizar estado*). **Ojo:** la API v2 en modo prueba clásico rechazó el enlace de registro ("Please switch to an account created in a sandbox"); puede requerir una *sandbox* de Stripe |
| 2 | **Webhook de Stripe** | Si `STRIPE_WEBHOOK_SECRET` no tiene el `whsec_` real, las citas se quedan en "Esperando pago" | Stripe → Desarrolladores → Webhooks → destino `…/stripeWebhook` con `checkout.session.completed` y `checkout.session.expired` → guardar el secreto (ver PAGOS_STRIPE.md, paso 6) |
| 3 | **Publicar en Google Play** | Falta pagar la cuenta de desarrollador (**US$25**, un solo pago) | Juntar el pago. Mientras tanto, preparar lo de la sección "Antes de Play Store" |
| 4 | **Prueba cerrada de Play** | Las cuentas personales nuevas necesitan **12 testers durante 14 días seguidos** antes de publicar | Conseguir unos 15 compañeros con Android y sus correos de Gmail |

## 🟡 Hecho, falta configurar o probar

- [ ] Publicar la última versión del servidor: `firebase deploy --only functions`.
- [ ] Publicar reglas: `firebase deploy --only "storage,firestore:rules"`.
- [ ] **Storage** activado en la consola (para videos).
- [ ] Activar el proveedor **Correo electrónico/contraseña** en Firebase Authentication.
- [ ] Prueba completa de pago: reservar → pagar con 4242… → "¡Cita confirmada!" → verlo en
      Agenda y en Cobros y ventas → cancelar con más de 24 h → que se vea el reembolso.
- [ ] Compra de un producto (descuenta existencias) y que aparezca en *Ventas de productos*.
- [ ] Agregar tarjeta en Billetera con 4242… y quitarla.
- [ ] Subir un video en Publicaciones y ver que se reproduzca solo en Novedades.
- [ ] *Cerca de ti* en un celular Android real moviéndose (permiso de ubicación).
- [ ] Anuncios de prueba de AdMob en Android (en la web no salen, es normal).
- [ ] Correr `flutter test` y `npm test` después de los últimos cambios.
- [ ] Llenar los nombres pendientes en la ficha técnica de Proyéctate.

## ⬜ Antes de Play Store (obligatorio para Google)

- [ ] **Borrar cuenta** desde la app y con un enlace web. Google lo exige porque se pueden
      crear cuentas. (En la app y en el servidor ya está hecho: falta publicar la función y
      probarla. TODO: enlace web, ver BORRAR_CUENTA.md.)
- [ ] **Política de privacidad** publicada (enlace): qué datos se usan (correo, nombre, fotos,
      ubicación solo en el teléfono, pagos con Stripe).
- [ ] Formulario de **Seguridad de los datos** y casilla **"Contiene anuncios"**.
- [ ] Cuenta de **AdMob** propia: cambiar los IDs de prueba en `lib/config/ads_config.dart` y
      `AndroidManifest.xml`, y bloquear categorías sensibles (ver ANUNCIOS.md).
- [ ] Ícono de la app, nombre del paquete definitivo (`applicationId`) y llave de firma
      (keystore) para el release.
- [ ] Generar el `.aab`: `flutter build appbundle`.
- [ ] Capturas de pantalla y descripción para la ficha de Play.
- [ ] Agregar el SHA-1 de la llave de release a Firebase (para el inicio de sesión con Google).

## ⬜ Para cobrar dinero real (después)

- [ ] Verificar la empresa en Stripe con datos reales (RFC, CLABE, identificación).
- [ ] Cambiar a la llave `sk_live_` y crear el webhook en modo real.
- [ ] Revisar el porcentaje de comisión (hoy 5 %) y la política de cancelación (24 h).
- [ ] Activar **App Check** (`ENFORCE_APP_CHECK = true` en `functions/index.js`).

## ⬜ Mejoras propuestas

- [ ] Notificaciones push (Firebase Cloud Messaging): nueva cita, recordatorio un día antes,
      cancelación.
- [ ] Reseñas y calificaciones verificadas (solo quien tuvo una cita confirmada).
- [ ] Recordatorio por correo 24 h antes (función programada).
- [ ] Miniatura o primer cuadro del video antes de que cargue.
- [ ] Comprimir los videos antes de subirlos (hoy se suben tal cual, máx. 50 MB).
- [ ] Mover las imágenes de base64 a Storage (ya hay plan Blaze) para que la app cargue más rápido.
- [ ] Búsqueda por servicio ("corte de cabello") y no solo por nombre del negocio.
- [ ] Filtros en *Cerca de ti* (radio de distancia, solo abiertos ahora).
- [ ] Horario distinto por día de la semana (hoy es el mismo todos los días que abre).
- [ ] Probar y ajustar en **iOS**: falta el permiso de ubicación en `Info.plist` y el ID de AdMob.
- [ ] La pantalla `videos_screen.dart` está vacía; borrarla o darle uso.
- [ ] Pruebas de widgets (hoy solo hay pruebas de la lógica).

## ⚠ Problemas conocidos

- Las citas creadas antes del servidor de pagos no tienen registro en `busy`, así que no se ven
  ocupadas para otros clientes. El servidor de todas formas impide reservar encima. Son datos de
  prueba viejos.
- Nominatim (buscar dirección en el mapa) permite **1 búsqueda por segundo**. Con muchos negocios
  sin ubicación marcada, *Cerca de ti* tarda en mostrarlos. Solución: que cada negocio marque su
  punto en el mapa.
- `flutter run -d chrome` abre un Chrome sin sesiones, por eso Google no muestra tus cuentas. Usa
  `-d web-server` y tu Chrome normal.
- En la web, los videos empiezan sin sonido (regla de los navegadores).
- En modo prueba Stripe **rechaza tarjetas reales** (BBVA, Nu…). Solo acepta las de prueba
  (4242…). Es lo esperado.

## ✅ Terminado

- **Cuentas:** inicio de sesión con Google y con correo + contraseña, verificación de correo y
  recuperación de contraseña.
- **Perfiles:** cliente y negocio en la misma cuenta, con cambio de interfaz.
- **Registro del negocio:** categoría ("Otros" con texto libre), personal con turnos y días de
  descanso, ubicación en el mapa.
- **Agenda:**
  - Horarios por persona ("Te atiende…").
  - Bloqueo de empalmes en el servidor y apartado de 30 min mientras se paga.
  - Reprogramar y cancelar, con política de 24 h.
  - El negocio puede agregar clientes a mano.
- **Pagos con Stripe:** anticipo del 25 %, compra de productos, billetera con tarjetas guardadas,
  reembolsos automáticos, movimientos y comisión del 5 %, Connect Express para los negocios.
- **Seguridad:** reglas cerradas, montos calculados en el servidor, webhook firmado, límite de
  intentos, correo verificado y mensajes de error claros.
- **Sitio del negocio:**
  - Portada, logo, paleta y redes.
  - Pestañas: Servicios, Productos, Fotos, Novedades e **Información** (mapa, Cómo llegar,
    horario semanal, quién atiende, contacto).
- **Catálogo:** clasificaciones elegidas por el negocio; carrusel cuando hay clasificación,
  cuadrícula cuando no.
- **Publicaciones:**
  - Con foto o video (Storage), con autoplay y pausa según la vista.
  - Novedades agrupadas por negocio en carrusel; se ocultan después de 8 días.
- **Cerca de ti:** mapa con la ubicación en vivo, negocios cercanos con distancia y si están
  abiertos.
- **Anuncios AdMob:** solo aptos para todo público y nunca en pantallas de pago.
- **Nueva paleta de colores.**
- **Avisos por correo (EmailJS):** nueva cita, cancelación, reprogramación, venta.
- **Documentos:** README, guías de Firebase, Stripe y anuncios, y ficha técnica de Proyéctate
  (Word).
