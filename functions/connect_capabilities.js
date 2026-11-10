// Lógica pura de las cuentas de cobro (Stripe Connect v2). Sin Firebase ni Stripe,
// para poder probarla con `npm test`.

/** Lee de una cuenta v2 si card_payments y stripe_transfers están activos. */
function connectCapabilities(account) {
  const cfg = (account && account.configuration) || {};
  const cardPayments = cfg.merchant && cfg.merchant.capabilities && cfg.merchant.capabilities.card_payments;
  const balance = cfg.recipient && cfg.recipient.capabilities && cfg.recipient.capabilities.stripe_balance;
  const transfers = balance && balance.stripe_transfers;
  return {
    cardPayments: Boolean(cardPayments && cardPayments.status === 'active'),
    transfers: Boolean(transfers && transfers.status === 'active'),
  };
}

/** ¿El registro guardado en stripeAccounts es de una cuenta v2 con id? Los viejos (v1 Express) no. */
function isV2Record(record) {
  return Boolean(record && record.apiVersion === 'v2' && record.accountId);
}

/** El registro cuenta como cuenta conectada solo si es v2. Los viejos se ignoran. */
function usableAccount(record) {
  return isV2Record(record) ? record : null;
}

module.exports = {connectCapabilities, isV2Record, usableAccount};
