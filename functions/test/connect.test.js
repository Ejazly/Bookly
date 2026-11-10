// Pruebas de la lógica pura de cuentas v2 (sin llamar a Stripe ni Firebase).
const test = require('node:test');
const assert = require('node:assert');
const {connectCapabilities, isV2Record, usableAccount} = require('../connect_capabilities');

test('cuenta v2 activa', () => {
  const r = connectCapabilities({configuration: {
    merchant: {capabilities: {card_payments: {status: 'active'}}},
    recipient: {capabilities: {stripe_balance: {stripe_transfers: {status: 'active'}}}},
  }});
  assert.deepStrictEqual(r, {cardPayments: true, transfers: true});
});

test('cuenta v2 pendiente o vacía', () => {
  assert.deepStrictEqual(connectCapabilities({configuration: {merchant: {capabilities: {card_payments: {status: 'restricted'}}}}}),
    {cardPayments: false, transfers: false});
  assert.deepStrictEqual(connectCapabilities({}), {cardPayments: false, transfers: false});
  assert.deepStrictEqual(connectCapabilities(null), {cardPayments: false, transfers: false});
});

test('registro v2 con id es cuenta conectada', () => {
  const rec = {accountId: 'acct_1', apiVersion: 'v2', chargesEnabled: true};
  assert.strictEqual(isV2Record(rec), true);
  assert.strictEqual(usableAccount(rec), rec);
});

test('registro viejo (sin apiVersion o v1) no cuenta como conectado', () => {
  assert.strictEqual(isV2Record({accountId: 'acct_old', chargesEnabled: true}), false);
  assert.strictEqual(usableAccount({accountId: 'acct_old', chargesEnabled: true}), null);
  assert.strictEqual(usableAccount({accountId: 'acct_old', apiVersion: 'v1'}), null);
});

test('sin registro o sin id no cuenta', () => {
  assert.strictEqual(usableAccount(null), null);
  assert.strictEqual(usableAccount(undefined), null);
  assert.strictEqual(usableAccount({apiVersion: 'v2'}), null);
});
