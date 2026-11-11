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

## Enlace web (pendiente)
Google pide una URL pública. Opciones:
- Más simple: en la página de la política de privacidad, explicar que se borra desde
  Perfil → Borrar mi cuenta, y que quien no pueda entrar escriba al correo de soporte; la autora
  borra el usuario en Firebase Console → Authentication y los datos con la función.
- Completa: una página web con inicio de sesión de Firebase que llame a `deleteAccount`.

Pendiente: publicar la función (`firebase deploy --only functions --project bookly-c0692`).
