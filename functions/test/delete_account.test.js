'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {blockingReasons, anonymizeAppointment, anonymizeOrder, chunk} = require('../delete_account');

const NOW = 1_000_000;
const ts = (ms) => ({toMillis: () => ms});

test('sin citas ni pedidos no hay bloqueos', () => {
  assert.deepEqual(blockingReasons({uid: 'u1', now: NOW}), []);
});

test('cita confirmada futura bloquea (como cliente o como negocio)', () => {
  const asClient = [{clientUid: 'u1', status: 'confirmada', start: ts(NOW + 1)}];
  const asBusiness = [{businessId: 'u1', status: 'confirmada', start: ts(NOW + 1)}];
  assert.equal(blockingReasons({uid: 'u1', appointments: asClient, now: NOW}).length, 1);
  assert.equal(blockingReasons({uid: 'u1', appointments: asBusiness, now: NOW}).length, 1);
});

test('citas pasadas, canceladas o de otras personas no bloquean', () => {
  const appts = [
    {clientUid: 'u1', status: 'confirmada', start: ts(NOW - 1)},
    {clientUid: 'u1', status: 'cancelada', start: ts(NOW + 5)},
    {clientUid: 'otro', businessId: 'x', status: 'confirmada', start: ts(NOW + 5)},
  ];
  assert.deepEqual(blockingReasons({uid: 'u1', appointments: appts, now: NOW}), []);
});

test('pagos pendientes bloquean (cita o pedido)', () => {
  const a = [{clientUid: 'u1', status: 'pendiente_pago', start: ts(NOW + 5)}];
  const o = [{buyerUid: 'u1', status: 'pendiente_pago'}];
  assert.equal(blockingReasons({uid: 'u1', appointments: a, now: NOW}).length, 1);
  assert.equal(blockingReasons({uid: 'u1', orders: o, now: NOW}).length, 1);
  assert.equal(blockingReasons({uid: 'u1', appointments: a, orders: o, now: NOW}).length, 1);
});

test('anonimizar cita quita datos personales y no toca montos', () => {
  const patch = anonymizeAppointment({clientUid: 'u1', clientName: 'Ana', clientEmail: 'a@a.com', depositPaid: 50}, 'u1');
  assert.deepEqual(patch, {clientUid: null, clientName: 'Usuario eliminado', clientEmail: ''});
  assert.equal('depositPaid' in patch, false);
  assert.equal(anonymizeAppointment({clientUid: 'otro'}, 'u1'), null);
});

test('anonimizar pedido', () => {
  const patch = anonymizeOrder({buyerUid: 'u1', buyerName: 'Ana', buyerEmail: 'a@a.com'}, 'u1');
  assert.deepEqual(patch, {buyerUid: null, buyerName: 'Usuario eliminado', buyerEmail: ''});
  assert.equal(anonymizeOrder({buyerUid: 'otro'}, 'u1'), null);
});

test('chunk respeta el máximo de 500', () => {
  const parts = chunk(Array.from({length: 1201}, (_, i) => i), 500);
  assert.deepEqual(parts.map((p) => p.length), [500, 500, 201]);
  assert.deepEqual(chunk([]), []);
});
