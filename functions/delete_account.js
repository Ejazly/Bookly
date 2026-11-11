'use strict';

/**
 * Lógica pura de "Borrar cuenta" (sin Firebase, para poder probarla con npm test).
 */

const ANON_NAME = 'Usuario eliminado';
const ANON_EMAIL = '';

function millis(value) {
  if (value && typeof value.toMillis === 'function') return value.toMillis();
  if (value instanceof Date) return value.getTime();
  return Number(value) || 0;
}

/**
 * Revisa qué impide borrar la cuenta. Regresa una lista de mensajes en español
 * (vacía = se puede borrar).
 *
 * - citas: citas donde la persona es cliente o dueña del negocio.
 * - orders: pedidos donde es compradora o vendedora.
 */
function blockingReasons({uid, appointments = [], orders = [], now = Date.now()}) {
  const reasons = [];
  const mine = (a) => a.clientUid === uid || a.businessId === uid;
  const futureConfirmed = appointments.filter(
    (a) => mine(a) && a.status === 'confirmada' && millis(a.start) > now,
  ).length;
  const pendingAppointments = appointments.filter((a) => mine(a) && a.status === 'pendiente_pago').length;
  const pendingOrders = orders.filter(
    (o) => (o.buyerUid === uid || o.businessId === uid) && o.status === 'pendiente_pago',
  ).length;

  if (futureConfirmed > 0) {
    reasons.push(
      `Tienes ${futureConfirmed} cita(s) confirmada(s) por venir. Cancélalas o espera a que pasen antes de borrar tu cuenta.`,
    );
  }
  if (pendingAppointments + pendingOrders > 0) {
    reasons.push(
      'Tienes pagos pendientes. Termínalos o cancélalos (o espera unos 30 minutos a que expiren) antes de borrar tu cuenta.',
    );
  }
  return reasons;
}

/**
 * Campos a cambiar en una cita para quitar los datos personales de `uid`,
 * conservando montos y fechas (contabilidad). Regresa null si no figura.
 */
function anonymizeAppointment(doc, uid) {
  if (doc.clientUid !== uid) return null;
  return {clientUid: null, clientName: ANON_NAME, clientEmail: ANON_EMAIL};
}

/** Igual que la anterior, para pedidos de productos. */
function anonymizeOrder(doc, uid) {
  if (doc.buyerUid !== uid) return null;
  return {buyerUid: null, buyerName: ANON_NAME, buyerEmail: ANON_EMAIL};
}

/** Parte una lista en grupos de `size` (los lotes de Firestore admiten 500). */
function chunk(list, size = 500) {
  const out = [];
  for (let i = 0; i < list.length; i += size) out.push(list.slice(i, i + size));
  return out;
}

module.exports = {ANON_NAME, ANON_EMAIL, blockingReasons, anonymizeAppointment, anonymizeOrder, chunk};
