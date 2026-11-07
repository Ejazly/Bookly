'use strict';

// Pruebas de la lógica de horarios del servidor.  Ejecutar:  npm test
const test = require('node:test');
const assert = require('node:assert');
const {localParts, checkBusinessHours, pickProfessional, teamOf} = require('../schedule');

// Martes 27 de octubre de 2026 en Querétaro (UTC-6).
const at = (h, m = 0) => Date.UTC(2026, 9, 27, h + 6, m);

const business = {
  openHour: 10,
  closeHour: 20,
  closedWeekdays: [7],
  staff: [
    {name: 'Evelyn', startHour: 10, endHour: 16, daysOff: [1]},
    {name: 'Sandy', startHour: 14, endHour: 20, daysOff: []},
  ],
};

test('convierte la hora a la de Querétaro', () => {
  const p = localParts(at(16));
  assert.equal(p.dayKey, '2026-10-27');
  assert.equal(p.weekday, 2); // martes
  assert.equal(p.minutesOfDay, 16 * 60);
});

test('rechaza horarios fuera del horario del negocio o que no son en punto', () => {
  assert.equal(checkBusinessHours(business, at(9), 60).ok, false);
  assert.equal(checkBusinessHours(business, at(19, 30), 60).ok, false);
  assert.equal(checkBusinessHours(business, at(19), 120).ok, false); // terminaría 21:00
  assert.equal(checkBusinessHours(business, at(16), 60).ok, true);
});

test('rechaza el día que cierra el negocio', () => {
  const domingo = Date.UTC(2026, 10, 1, 16);
  assert.equal(checkBusinessHours(business, domingo, 60).ok, false);
});

test('asigna a quien está en turno', () => {
  const now = at(8);
  assert.equal(pickProfessional({business, startMs: at(11), minutes: 60, existing: [], nowMs: now}), 'Evelyn');
  assert.equal(pickProfessional({business, startMs: at(18), minutes: 60, existing: [], nowMs: now}), 'Sandy');
  assert.equal(
    pickProfessional({business, startMs: at(18), minutes: 60, existing: [], preferred: 'Evelyn', nowMs: now}),
    null,
  );
});

test('no permite reservar dos veces el mismo horario', () => {
  const now = at(8);
  const existing = [{id: 'a', professional: 'Sandy', startMs: at(18), minutes: 60, status: 'confirmada'}];
  assert.equal(pickProfessional({business, startMs: at(18), minutes: 60, existing, nowMs: now}), null);
  // A las 14:00 están las dos; si Evelyn está ocupada, toca Sandy.
  const busyEvelyn = [{id: 'b', professional: 'Evelyn', startMs: at(14), minutes: 60, status: 'confirmada'}];
  assert.equal(pickProfessional({business, startMs: at(14), minutes: 60, existing: busyEvelyn, nowMs: now}), 'Sandy');
});

test('un apartado sin pagar que ya venció libera el horario', () => {
  const now = at(8);
  const vencido = {toMillis: () => now - 1000};
  const vigente = {toMillis: () => now + 60000};
  const base = {id: 'c', professional: 'Sandy', startMs: at(18), minutes: 60, status: 'pendiente_pago'};
  assert.equal(
    pickProfessional({business, startMs: at(18), minutes: 60, existing: [{...base, holdExpiresAt: vencido}], nowMs: now}),
    'Sandy',
  );
  assert.equal(
    pickProfessional({business, startMs: at(18), minutes: 60, existing: [{...base, holdExpiresAt: vigente}], nowMs: now}),
    null,
  );
});

test('al reprogramar la cita no choca consigo misma', () => {
  const now = at(8);
  const existing = [{id: 'yo', professional: 'Sandy', startMs: at(18), minutes: 60, status: 'confirmada'}];
  assert.equal(
    pickProfessional({business, startMs: at(18), minutes: 60, existing, ignoreId: 'yo', nowMs: now}),
    'Sandy',
  );
});

test('negocios viejos sin turnos usan el horario completo', () => {
  const team = teamOf({openHour: 9, closeHour: 18, professionals: ['Luis']});
  assert.deepEqual(team, [{name: 'Luis', startHour: 9, endHour: 18, daysOff: []}]);
});
