# Borrar cuenta en Bookly

Google Play exige poder borrar la cuenta desde la app **y** tener un enlace web.

## Desde la app (ya hecho)
Perfil → **Borrar mi cuenta** → escribir `BORRAR`. La app llama a la función `deleteAccount`
(`functions/index.js`); la lógica pura está en `functions/delete_account.js`.

La función:
1. **Rechaza** si hay citas confirmadas por venir (como cliente o como negocio) o pagos pendientes.
2. **Anonimiza** (nombre "Usuario eliminado", sin correo) las citas y pedidos del usuario como
   cliente/comprador, conservando montos y fechas para contabilidad.
3. **Borra**: `users/{uid}` (con `movements`), `businesses/{uid}` (con `items`, `gallery`, `busy`,
   `movements`), sus `posts`, los videos de Storage `posts/{uid}/`, `paymentStatus/{uid}`,
   `stripeCustomers/{uid}` (y el cliente en Stripe) y el vínculo `stripeAccounts/{uid}`.
4. Borra el usuario de Firebase Auth.

Notas: la cuenta Connect de Stripe **no se elimina** automáticamente (puede tener saldo); su id
queda en el registro de la función (`firebase functions:logs`) para cerrarla a mano en Stripe.
Las citas pasadas de un negocio borrado quedan en el historial de sus clientes.

## Enlace web (hecho, falta publicar)
La página está en `public/borrar-cuenta.html` (Firebase Hosting, configurado en `firebase.json`).
Explica qué se borra y qué se conserva, pide iniciar sesión (Google o correo + contraseña),
pide escribir `BORRAR` y llama a `deleteAccount`. Muestra los errores en español (por ejemplo,
citas por venir). Solo lleva la configuración web **pública** de Firebase; no hay llaves secretas.

Pasos:
1. Poner tu correo real en lugar de `[CORREO DE CONTACTO]` dentro de `public/borrar-cuenta.html`.
2. Publicar la página:
   ```powershell
   firebase deploy --only hosting --project bookly-c0692
   ```
3. La URL para **Play Console** (Contenido de la app → Eliminación de datos) es:
   `https://bookly-c0692.web.app/borrar-cuenta` (también funciona en
   `https://bookly-c0692.firebaseapp.com/borrar-cuenta`).
4. Paso manual: Firebase Console → Authentication → Configuración → Dominios autorizados.
   `bookly-c0692.web.app` y `bookly-c0692.firebaseapp.com` suelen venir ya autorizados; si el botón
   de Google dice que el dominio no está autorizado, agrégalo ahí.
5. Probar con una cuenta de prueba (no la tuya real) y confirmar que el usuario desaparece de
   Authentication.

Pendiente: publicar la función (`firebase deploy --only functions --project bookly-c0692`);
sin ella la página no puede borrar nada.
