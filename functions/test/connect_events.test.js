const test = require('node:test');
const assert = require('node:assert');
const {isRelevantType, accountIdFromNotification, decideNotification} = require('../connect_events');

const merchant = 'v2.core.account[configuration.merchant].capability_status_updated';
const recipient = 'v2.core.account[configuration.recipient].capability_status_updated';

test('tipos relevantes', () => {
  assert.ok(isRelevantType(merchant));
  assert.ok(isRelevantType(recipient));
  assert.ok(!isRelevantType('v2.core.account[configuration.customer].capability_status_updated'));
  assert.ok(!isRelevantType('checkout.session.completed'));
});

test('accountId desde related_object', () => {
  assert.strictEqual(accountIdFromNotification({related_object: {id: 'acct_123', type: 'v2.core.account'}}), 'acct_123');
  assert.strictEqual(accountIdFromNotification({related_object: {id: 'acct_123'}}), 'acct_123');
  assert.strictEqual(accountIdFromNotification({related_object: {id: 'cus_1', type: 'customer'}}), null);
  assert.strictEqual(accountIdFromNotification({related_object: {id: '../x', type: 'v2.core.account'}}), null);
  assert.strictEqual(accountIdFromNotification({}), null);
  assert.strictEqual(accountIdFromNotification(null), null);
});

test('decideNotification', () => {
  const ok = decideNotification({id: 'evt_1', type: merchant, related_object: {id: 'acct_9', type: 'v2.core.account'}});
  assert.deepStrictEqual(ok, {process: true, accountId: 'acct_9'});
  assert.strictEqual(decideNotification({id: 'evt_1', type: 'otro', related_object: {id: 'acct_9'}}).process, false);
  assert.strictEqual(decideNotification({id: 'evt_1', type: recipient}).reason, 'sin-cuenta');
  assert.strictEqual(decideNotification({type: recipient, related_object: {id: 'acct_9'}}).reason, 'sin-id');
});
