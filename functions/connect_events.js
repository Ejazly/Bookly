// Lógica pura para los avisos "thin" (v2) de Stripe sobre cuentas conectadas.
// Sin Firebase ni Stripe, para poder probarla con `npm test`.

// Eventos que cambian si una cuenta puede cobrar. Ver PAGOS_STRIPE.md.
const RELEVANT_TYPES = [
  'v2.core.account[configuration.merchant].capability_status_updated',
  'v2.core.account[configuration.recipient].capability_status_updated',
];

/** ¿Este tipo de aviso obliga a recalcular el estado de cobro? */
function isRelevantType(type) {
  return RELEVANT_TYPES.includes(type);
}

/** Id de la cuenta v2 (acct_...) a la que se refiere el aviso, o null si no se puede saber. */
function accountIdFromNotification(notification) {
  const rel = notification && notification.related_object;
  if (!rel || typeof rel.id !== 'string') return null;
  if (rel.type && rel.type !== 'v2.core.account') return null;
  return /^acct_[A-Za-z0-9]+$/.test(rel.id) ? rel.id : null;
}

/**
 * Decide qué hacer con un aviso ya verificado: {process: true, accountId} o
 * {process: false, reason}.
 */
function decideNotification(notification) {
  if (!notification || typeof notification.id !== 'string' || !notification.id) {
    return {process: false, reason: 'sin-id'};
  }
  if (!isRelevantType(notification.type)) return {process: false, reason: 'tipo-ignorado'};
  const accountId = accountIdFromNotification(notification);
  if (!accountId) return {process: false, reason: 'sin-cuenta'};
  return {process: true, accountId};
}

module.exports = {RELEVANT_TYPES, isRelevantType, accountIdFromNotification, decideNotification};
