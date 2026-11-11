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

// ---- Horario distinto por día (weeklyHours) ----
// Estos mismos casos y resultados están en test/weekly_hours_test.dart: si
// cambias uno, cambia el otro para que Dart y JS sigan dando lo mismo.
const {hoursFor} = require('../schedule');

// Semana del lunes 26 de octubre de 2026 (lunes = 0 ... domingo = 6).
const dayAt = (offset, h) => Date.UTC(2026, 9, 26 + offset, h + 6);
const range = (a, b) => Array.from({length: b - a + 1}, (_, i) => a + i);

const weekly = {
  openHour: 9,
  closeHour: 19,
  closedWeekdays: [7],
  weeklyHours: {
    1: {open: 10, close: 14},
    2: {open: 9, close: 19},
    3: {open: 9, close: 19},
    4: {open: 9, close: 19},
    5: {open: 9, close: 19},
    6: {open: 10, close: 16},
    7: null,
  },
  staff: [
    {name: 'Evelyn', startHour: 10, endHour: 16, daysOff: [1]},
    {name: 'Sandy', startHour: 14, endHour: 20, daysOff: []},
  ],
};

const slotHours = (b, offset, minutes) =>
  range(0, 23).filter((h) => checkBusinessHours(b, dayAt(offset, h), minutes).ok);
const memberHours = (b, offset, minutes, name) =>
  // Igual que el servidor: primero el horario del negocio, luego el turno.
  range(0, 23).filter((h) => checkBusinessHours(b, dayAt(offset, h), minutes).ok && pickProfessional({
    business: b, startMs: dayAt(offset, h), minutes, existing: [], preferred: name, nowMs: 0,
  }) === name);

test('sin weeklyHours el negocio se comporta igual que antes', () => {
  assert.deepEqual(hoursFor(business, 2), {open: 10, close: 20});
  assert.equal(hoursFor(business, 7), null);
  assert.deepEqual(slotHours(business, 1, 60), range(10, 19)); // martes
  assert.deepEqual(slotHours(business, 6, 60), []); // domingo
});

test('weeklyHours: lunes distinto de sábado y domingo cerrado', () => {
  assert.deepEqual(slotHours(weekly, 0, 60), [10, 11, 12, 13]); // lunes
  assert.deepEqual(slotHours(weekly, 1, 60), range(9, 18)); // martes
  assert.deepEqual(slotHours(weekly, 5, 60), range(10, 15)); // sábado
  assert.deepEqual(slotHours(weekly, 6, 60), []); // domingo cerrado
  assert.deepEqual(slotHours(weekly, 0, 120), [10, 11, 12]);
  assert.deepEqual(slotHours(weekly, 5, 120), range(10, 14));
  assert.equal(checkBusinessHours(weekly, dayAt(6, 12), 60).ok, false);
});

test('weeklyHours: turnos del personal y días de descanso', () => {
  assert.deepEqual(memberHours(weekly, 0, 60, 'Evelyn'), []); // descansa lunes
  assert.deepEqual(memberHours(weekly, 0, 60, 'Sandy'), []); // lunes cierra a las 14
  assert.deepEqual(memberHours(weekly, 1, 60, 'Evelyn'), range(10, 15));
  assert.deepEqual(memberHours(weekly, 1, 60, 'Sandy'), range(14, 18)); // tope 19:00
  assert.deepEqual(memberHours(weekly, 5, 60, 'Sandy'), [14, 15]); // sábado cierra 16
  assert.deepEqual(memberHours(weekly, 6, 60, 'Sandy'), []);
});

test('weeklyHours: día ausente o inválido usa el horario general', () => {
  const b = {openHour: 10, closeHour: 20, closedWeekdays: [3], weeklyHours: {1: {open: 12, close: 8}, 2: {open: 8, close: 12}}};
  assert.deepEqual(hoursFor(b, 1), {open: 10, close: 20}); // inválido
  assert.deepEqual(hoursFor(b, 2), {open: 8, close: 12});
  assert.equal(hoursFor(b, 3), null); // ausente y cerrado en el general
  assert.deepEqual(hoursFor(b, 4), {open: 10, close: 20});
});
