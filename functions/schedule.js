'use strict';

// Lógica de horarios del SERVIDOR. Es la misma que lib/logic/schedule.dart,
// pero aquí es la que manda: aunque alguien modifique la app, el servidor
// vuelve a revisar el horario antes de apartar la cita o cobrar.

const TIME_ZONE = 'America/Mexico_City';
const SLOT_STEP_MINUTES = 60;

const formatter = new Intl.DateTimeFormat('en-CA', {
  timeZone: TIME_ZONE,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
  weekday: 'short',
  hourCycle: 'h23',
});

const WEEKDAYS = {Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6, Sun: 7};

/** Fecha y hora en Querétaro (no en la hora del servidor). */
function localParts(ms) {
  const parts = {};
  for (const p of formatter.formatToParts(new Date(ms))) parts[p.type] = p.value;
  return {
    dayKey: `${parts.year}-${parts.month}-${parts.day}`,
    weekday: WEEKDAYS[parts.weekday],
    minutesOfDay: Number(parts.hour) * 60 + Number(parts.minute),
  };
}

function toInt(v, fallback) {
  return Number.isInteger(v) ? v : fallback;
}

/** Personal con su turno (igual que Business.team en la app). */
function teamOf(business) {
  const open = toInt(business.openHour, 9);
  const close = toInt(business.closeHour, 19);
  const staff = Array.isArray(business.staff) ? business.staff : [];
  const fromStaff = staff
    .filter((m) => m && typeof m.name === 'string' && m.name.trim())
    .map((m) => ({
      name: m.name.trim(),
      startHour: toInt(m.startHour, open),
      endHour: toInt(m.endHour, close),
      daysOff: Array.isArray(m.daysOff) ? m.daysOff.filter(Number.isInteger) : [],
    }));
  if (fromStaff.length) return fromStaff;
  const names = Array.isArray(business.professionals) && business.professionals.length
    ? business.professionals.filter((n) => typeof n === 'string' && n.trim())
    : ['Personal'];
  return names.map((n) => ({name: n.trim(), startHour: open, endHour: close, daysOff: []}));
}

/**
 * ¿El horario cae dentro del horario del negocio, en un día que abre y
 * en punto (10:00, 11:00...)? Regresa la información del día o lanza un error.
 */
function checkBusinessHours(business, startMs, minutes) {
  const local = localParts(startMs);
  const closed = Array.isArray(business.closedWeekdays) ? business.closedWeekdays : [];
  if (closed.includes(local.weekday)) return {ok: false, reason: 'El negocio no abre ese día.'};
  const open = toInt(business.openHour, 9) * 60;
  const close = toInt(business.closeHour, 19) * 60;
  const start = local.minutesOfDay;
  if ((start - open) % SLOT_STEP_MINUTES !== 0) {
    return {ok: false, reason: 'Ese horario no es válido.'};
  }
  if (start < open || start + minutes > close) {
    return {ok: false, reason: 'Ese horario está fuera del horario del negocio.'};
  }
  return {ok: true, local};
}

/** ¿La persona trabaja en ese horario (turno y días de descanso)? */
function memberWorks(member, local, minutes) {
  if (member.daysOff.includes(local.weekday)) return false;
  const start = local.minutesOfDay;
  return start >= member.startHour * 60 && start + minutes <= member.endHour * 60;
}

/** Una cita ocupa el horario si está confirmada o apartada sin vencer. */
function isActive(appt, nowMs) {
  if (appt.status === 'confirmada') return true;
  if (appt.status === 'pendiente_pago') {
    const until = appt.holdExpiresAt && appt.holdExpiresAt.toMillis
      ? appt.holdExpiresAt.toMillis()
      : 0;
    return until > nowMs;
  }
  return false;
}

/**
 * Busca quién puede atender. [existing] son las citas del día como
 * {id, professional, startMs, minutes, status, holdExpiresAt}.
 */
function pickProfessional({business, startMs, minutes, existing, preferred, ignoreId, nowMs}) {
  const local = localParts(startMs);
  const team = teamOf(business);
  const candidates = preferred ? team.filter((m) => m.name === preferred) : team;
  const endMs = startMs + minutes * 60000;
  for (const m of candidates) {
    if (!memberWorks(m, local, minutes)) continue;
    const busy = existing.some((a) =>
      a.id !== ignoreId &&
      a.professional === m.name &&
      isActive(a, nowMs) &&
      a.startMs < endMs &&
      startMs < a.startMs + a.minutes * 60000);
    if (!busy) return m.name;
  }
  return null;
}

module.exports = {
  TIME_ZONE,
  localParts,
  teamOf,
  checkBusinessHours,
  memberWorks,
  isActive,
  pickProfessional,
};
