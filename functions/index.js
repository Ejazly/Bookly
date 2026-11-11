'use strict';

/**
 * Servidor de pagos de Bookly (Firebase Cloud Functions + Stripe).
 *
 * REGLAS DE SEGURIDAD QUE SIGUE ESTE ARCHIVO
 *  1. La app NUNCA ve ni guarda números de tarjeta: los captura Stripe en su
 *     propia página (Stripe Checkout). Bookly solo guarda ids y últimos 4 dígitos.
 *  2. Los montos se calculan AQUÍ con los precios de la base de datos.
 *     Lo que mande la app (precio, anticipo) se ignora.
 *  3. Solo este servidor puede crear o cambiar citas, pedidos y movimientos
 *     (las reglas de Firestore lo prohíben a la app).
 *  4. Una cita se confirma solo cuando Stripe avisa que el pago entró
 *     (webhook con firma verificada), no cuando la app "dice" que pagó.
 *  5. Cada negocio recibe el dinero en SU cuenta de Stripe (Connect). Bookly
 *     nunca guarda la cuenta bancaria del negocio.
 *  6. Las llaves secretas viven en Secret Manager, nunca en el código ni en la app.
 *  7. Todo se valida (tipos, rangos, dueño del recurso) y hay límite de
 *     peticiones por usuario para evitar abusos.
 */

const {onCall, onRequest, HttpsError} = require('firebase-functions/v2/https');
const {setGlobalOptions} = require('firebase-functions/v2');
const {defineSecret} = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const {initializeApp} = require('firebase-admin/app');
const {getFirestore, FieldValue, Timestamp} = require('firebase-admin/firestore');
const {getAuth} = require('firebase-admin/auth');
const {getStorage} = require('firebase-admin/storage');
const Stripe = require('stripe');
const {
  blockingReasons, anonymizeAppointment, anonymizeOrder, chunk: chunkList,
} = require('./delete_account');
const {checkBusinessHours, pickProfessional} = require('./schedule');
const {connectCapabilities, usableAccount} = require('./connect_capabilities');
const {decideNotification} = require('./connect_events');

initializeApp();
const db = getFirestore();

const REGION = 'us-central1';
setGlobalOptions({region: REGION, maxInstances: 10});

// Llaves secretas (se guardan con `firebase functions:secrets:set ...`).
const STRIPE_SECRET_KEY = defineSecret('STRIPE_SECRET_KEY');
const STRIPE_WEBHOOK_SECRET = defineSecret('STRIPE_WEBHOOK_SECRET');
const STRIPE_CONNECT_WEBHOOK_SECRET = defineSecret('STRIPE_CONNECT_WEBHOOK_SECRET');

// ---------------------------------------------------------------------------
// Configuración
// ---------------------------------------------------------------------------
const CURRENCY = 'mxn';
const DEPOSIT_RATE = 0.25; // anticipo del 25 %
const PLATFORM_FEE_RATE = 0.05; // comisión de Bookly sobre cada cobro
const MIN_CHARGE_CENTS = 1000; // Stripe no cobra menos de $10 MXN
const CHECKOUT_MINUTES = 31; // Stripe pide al menos 30 min de vigencia
const MAX_DAYS_AHEAD = 60;
const MAX_QUANTITY = 10;
// Cuando actives App Check en Firebase (ver guía), cambia esto a true.
const ENFORCE_APP_CHECK = false;

const callOptions = {
  secrets: [STRIPE_SECRET_KEY],
  enforceAppCheck: ENFORCE_APP_CHECK,
  memory: '256MiB',
  timeoutSeconds: 60,
};

let stripeClient = null;
function stripe() {
  if (!stripeClient) stripeClient = new Stripe(STRIPE_SECRET_KEY.value());
  return stripeClient;
}

function projectId() {
  if (process.env.GCLOUD_PROJECT) return process.env.GCLOUD_PROJECT;
  try {
    return JSON.parse(process.env.FIREBASE_CONFIG || '{}').projectId;
  } catch (_) {
    return '';
  }
}

/** Página a la que Stripe regresa a la persona después de pagar. */
function returnUrl(status) {
  return `https://${REGION}-${projectId()}.cloudfunctions.net/returnPage?s=${status}`;
}

// ---------------------------------------------------------------------------
// Validaciones
// ---------------------------------------------------------------------------
function fail(code, message) {
  throw new HttpsError(code, message);
}

/**
 * Envuelve una función para que los errores de Stripe lleguen a la app con
 * un mensaje claro (y queden en el registro: firebase functions:log).
 */
function safe(name, handler) {
  return async (request) => {
    try {
      return await handler(request);
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logger.error(`${name} falló`, {type: err && err.type, code: err && err.code, message: err && err.message});
      const type = err && err.type;
      if (type === 'StripeAuthenticationError') {
        fail('failed-precondition', 'La llave secreta de Stripe no es válida. Revisa STRIPE_SECRET_KEY (debe empezar con sk_test_) y vuelve a publicar las funciones.');
      }
      if (type === 'StripePermissionError') {
        fail('failed-precondition', 'La llave de Stripe no tiene permiso para esto. Usa la clave secreta estándar (sk_test_), no una restringida.');
      }
      if (/signed up for Connect/i.test(String(err && err.message))) {
        fail('failed-precondition', 'Activa Connect en tu cuenta de Stripe: Dashboard → Connect → Empezar.');
      }
      if (type === 'StripeInvalidRequestError') {
        fail('failed-precondition', `Stripe rechazó la solicitud: ${err.message}`);
      }
      if (type === 'StripeConnectionError' || type === 'StripeAPIError') {
        fail('unavailable', 'Stripe no respondió. Inténtalo de nuevo en un momento.');
      }
      throw err;
    }
  };
}

function requireAuth(request) {
  const auth = request.auth;
  if (!auth || !auth.uid) fail('unauthenticated', 'Inicia sesión para continuar.');
  const email = String(auth.token.email || '').toLowerCase();
  if (!email) fail('failed-precondition', 'Tu cuenta necesita un correo.');
  if (auth.token.email_verified === false) {
    fail('failed-precondition', 'Tu correo no está verificado.');
  }
  return {uid: auth.uid, email, name: String(auth.token.name || email.split('@')[0])};
}

const ID_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;

function readId(value, field) {
  if (typeof value !== 'string' || !ID_PATTERN.test(value)) fail('invalid-argument', `Dato inválido: ${field}.`);
  return value;
}

function readText(value, field, {max, required = false} = {}) {
  if (value === undefined || value === null || value === '') {
    if (required) fail('invalid-argument', `Falta: ${field}.`);
    return '';
  }
  if (typeof value !== 'string') fail('invalid-argument', `Dato inválido: ${field}.`);
  const text = value.trim();
  if (required && !text) fail('invalid-argument', `Falta: ${field}.`);
  if (text.length > max) fail('invalid-argument', `${field} es demasiado largo.`);
  // Sin caracteres de control (evita inyectar texto raro en correos o registros).
  // eslint-disable-next-line no-control-regex
  if (/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/.test(text)) {
    fail('invalid-argument', `${field} tiene caracteres no permitidos.`);
  }
  return text;
}

function readOptionalName(value, field) {
  const text = readText(value, field, {max: 60});
  return text || null;
}

function readEmail(value) {
  const text = readText(value, 'correo', {max: 120}).toLowerCase();
  if (text && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(text)) fail('invalid-argument', 'Correo no válido.');
  return text;
}

function readPhone(value) {
  const text = readText(value, 'teléfono', {max: 20});
  if (text && !/^[0-9 +()-]{7,20}$/.test(text)) fail('invalid-argument', 'Teléfono no válido.');
  return text;
}

function readStart(value) {
  if (!Number.isInteger(value)) fail('invalid-argument', 'Fecha no válida.');
  const now = Date.now();
  if (value <= now + 5 * 60000) fail('failed-precondition', 'Ese horario ya pasó.');
  if (value > now + MAX_DAYS_AHEAD * 86400000) {
    fail('invalid-argument', `Solo se puede agendar con ${MAX_DAYS_AHEAD} días de anticipación.`);
  }
  return value;
}

/** Revisa que un precio guardado en la base de datos sea razonable. */
function readPrice(value) {
  const price = Number(value);
  if (!Number.isFinite(price) || price <= 0 || price > 100000) {
    fail('failed-precondition', 'El precio de este servicio no es válido.');
  }
  return price;
}

function cents(amount) {
  return Math.round(amount * 100);
}

function feeFor(amountCents) {
  return Math.round(amountCents * PLATFORM_FEE_RATE);
}

function money(amountCents) {
  return `$${(amountCents / 100).toFixed(2)}`;
}

/** Límite de peticiones por usuario (por minuto) para frenar abusos. */
async function rateLimit(uid, action, maxPerMinute) {
  const ref = db.collection('rateLimits').doc(`${uid}_${action}`);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const now = Date.now();
    const data = snap.exists ? snap.data() : null;
    if (!data || now - data.windowStart > 60000) {
      tx.set(ref, {windowStart: now, count: 1});
      return;
    }
    if (data.count >= maxPerMinute) {
      fail('resource-exhausted', 'Demasiados intentos. Espera un minuto e inténtalo de nuevo.');
    }
    tx.update(ref, {count: data.count + 1});
  });
}

// ---------------------------------------------------------------------------
// Acceso a datos
// ---------------------------------------------------------------------------
async function getBusiness(businessId) {
  const snap = await db.collection('businesses').doc(businessId).get();
  if (!snap.exists) fail('not-found', 'El negocio no existe.');
  return snap.data();
}

async function getItem(businessId, itemId) {
  const snap = await db.collection('businesses').doc(businessId).collection('items').doc(itemId).get();
  if (!snap.exists) fail('not-found', 'Ese servicio o producto ya no existe.');
  const item = snap.data();
  if (item.active === false) fail('failed-precondition', 'Ese servicio o producto no está disponible.');
  return item;
}

/** Registro crudo de stripeAccounts (puede ser viejo, de la API v1). */
async function getStoredAccount(businessId) {
  const snap = await db.collection('stripeAccounts').doc(businessId).get();
  return snap.exists ? snap.data() : null;
}

/** Cuenta de Stripe v2 del negocio; los registros viejos (v1) cuentan como "sin cuenta". */
async function getConnectedAccount(businessId) {
  return usableAccount(await getStoredAccount(businessId));
}

/** ¿El servidor está usando la llave de PRUEBA de Stripe? */
function isTestMode() {
  return STRIPE_SECRET_KEY.value().startsWith('sk_test_');
}

/**
 * Cuenta a la que va el dinero. En MODO DE PRUEBA, si el negocio todavía
 * no conecta Stripe, el cobro se hace igual pero se queda en la cuenta de
 * Bookly ({accountId: null}). Con dinero real esto nunca pasa: se exige que
 * el negocio tenga sus cobros activos.
 */
async function requirePayableBusiness(businessId) {
  const account = await getConnectedAccount(businessId);
  if (account && account.chargesEnabled) return account;
  if (isTestMode()) return {accountId: null};
  fail('failed-precondition', 'Este negocio todavía no puede recibir pagos en línea.');
}

/** Datos para repartir el pago al negocio (vacío si se queda en Bookly). */
function transferFor(account, amountCents) {
  return account && account.accountId
    ? {application_fee_amount: feeFor(amountCents), transfer_data: {destination: account.accountId}}
    : {};
}

/** Reembolso completo; si el pago se repartió al negocio, se le descuenta a él. */
async function refundPayment(paymentIntentId, metadata, idempotencyKey) {
  const pi = await stripe().paymentIntents.retrieve(paymentIntentId);
  const split = Boolean(pi.transfer_data && pi.transfer_data.destination);
  return stripe().refunds.create({
    payment_intent: paymentIntentId,
    ...(split ? {reverse_transfer: true, refund_application_fee: true} : {}),
    metadata,
  }, {idempotencyKey});
}

/** Cliente de Stripe de cada usuario (para guardar sus tarjetas). */
async function ensureCustomer(user) {
  const ref = db.collection('stripeCustomers').doc(user.uid);
  const snap = await ref.get();
  if (snap.exists && snap.data().customerId) return snap.data().customerId;
  const customer = await stripe().customers.create(
    {email: user.email, name: user.name, metadata: {uid: user.uid}},
    {idempotencyKey: `customer-${user.uid}`},
  );
  await ref.set({customerId: customer.id, createdAt: FieldValue.serverTimestamp()});
  return customer.id;
}

async function existingCustomer(uid) {
  const snap = await db.collection('stripeCustomers').doc(uid).get();
  return snap.exists ? snap.data().customerId : null;
}

function busyRef(businessId, appointmentId) {
  return db.collection('businesses').doc(businessId).collection('busy').doc(appointmentId);
}

/** Citas del día dentro de una transacción (para evitar reservas dobles). */
async function dayAppointments(tx, businessId, dayKey) {
  const q = db.collection('appointments')
    .where('businessId', '==', businessId)
    .where('day', '==', dayKey);
  const snap = await tx.get(q);
  return snap.docs.map((d) => {
    const a = d.data();
    return {
      id: d.id,
      professional: a.professional,
      startMs: a.start.toMillis(),
      minutes: a.minutes,
      status: a.status,
      holdExpiresAt: a.holdExpiresAt,
    };
  });
}

/** Horario ocupado público: sin nombres, correos ni teléfonos. */
function busyData(appt) {
  return {
    day: appt.day,
    start: appt.start,
    minutes: appt.minutes,
    professional: appt.professional,
    status: appt.status,
    holdExpiresAt: appt.holdExpiresAt || null,
  };
}

function addMovement(tx, path, data) {
  tx.set(db.collection(path).doc(), {...data, createdAt: FieldValue.serverTimestamp()});
}

function whenText(startMs) {
  return new Date(startMs).toLocaleString('es-MX', {
    timeZone: 'America/Mexico_City',
    weekday: 'short',
    day: 'numeric',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  });
}

// ---------------------------------------------------------------------------
// Reservar una cita pagando el anticipo
// ---------------------------------------------------------------------------
exports.startBooking = onCall(callOptions, safe('startBooking', async (request) => {
  const user = requireAuth(request);
  await rateLimit(user.uid, 'booking', 10);
  const data = request.data || {};
  const businessId = readId(data.businessId, 'negocio');
  const itemId = readId(data.itemId, 'servicio');
  const startMs = readStart(data.start);
  const preferred = readOptionalName(data.professional, 'profesional');
  const note = readText(data.note, 'nota', {max: 300});

  const [business, item] = await Promise.all([getBusiness(businessId), getItem(businessId, itemId)]);
  if (item.kind !== 'servicio') fail('failed-precondition', 'Solo los servicios se pueden agendar.');
  const price = readPrice(item.price);
  const minutes = Number.isInteger(item.minutes) && item.minutes >= 15 && item.minutes <= 480 ? item.minutes : 60;
  const hours = checkBusinessHours(business, startMs, minutes);
  if (!hours.ok) fail('failed-precondition', hours.reason);

  // Solo los negocios de ejemplo (id demo_N) se confirman sin cobro.
  const isDemo = business.demo === true && /^demo_[0-9]+$/.test(businessId);
  const account = isDemo ? null : await requirePayableBusiness(businessId);
  const depositCents = cents(price * DEPOSIT_RATE);
  if (!isDemo && depositCents < MIN_CHARGE_CENTS) {
    fail('failed-precondition', 'El anticipo de este servicio es menor al mínimo de $10 MXN.');
  }

  const now = Date.now();
  const expiresAtSec = Math.floor(now / 1000) + CHECKOUT_MINUTES * 60;
  const apptRef = db.collection('appointments').doc();
  let appointment;

  await db.runTransaction(async (tx) => {
    const existing = await dayAppointments(tx, businessId, hours.local.dayKey);
    const pro = pickProfessional({business, startMs, minutes, existing, preferred, nowMs: now});
    if (!pro) fail('aborted', 'Ese horario ya no está disponible. Elige otro.');
    appointment = {
      businessId,
      businessName: business.name || '',
      ownerEmail: business.ownerEmail || '',
      itemId,
      serviceName: item.name || 'Servicio',
      minutes,
      price,
      depositPaid: 0,
      amountCents: isDemo ? 0 : depositCents,
      professional: pro,
      start: Timestamp.fromMillis(startMs),
      day: hours.local.dayKey,
      clientUid: user.uid,
      clientName: user.name,
      clientEmail: user.email,
      clientPhone: '',
      note,
      status: isDemo ? 'confirmada' : 'pendiente_pago',
      holdExpiresAt: isDemo ? null : Timestamp.fromMillis((expiresAtSec + 120) * 1000),
      createdByBusiness: false,
      demo: isDemo,
      createdAt: FieldValue.serverTimestamp(),
    };
    tx.set(apptRef, appointment);
    tx.set(busyRef(businessId, apptRef.id), busyData(appointment));
  });

  if (isDemo) return {appointmentId: apptRef.id, demo: true};

  try {
    const customerId = await ensureCustomer(user);
    const session = await stripe().checkout.sessions.create({
      mode: 'payment',
      customer: customerId,
      allowed_payment_method_types: ['card'],
      client_reference_id: apptRef.id,
      line_items: [{
        quantity: 1,
        price_data: {
          currency: CURRENCY,
          unit_amount: depositCents,
          product_data: {
            name: `Anticipo 25 % · ${appointment.serviceName}`,
            description: `${appointment.businessName} · ${whenText(startMs)} con ${appointment.professional}`,
          },
        },
      }],
      payment_intent_data: {
        ...transferFor(account, depositCents),
        description: `Anticipo Bookly · ${appointment.businessName}`,
        metadata: {kind: 'appointment', refId: apptRef.id, uid: user.uid},
      },
      metadata: {kind: 'appointment', refId: apptRef.id, uid: user.uid},
      saved_payment_method_options: {payment_method_save: 'enabled'},
      expires_at: expiresAtSec,
      success_url: returnUrl('pago_ok'),
      cancel_url: returnUrl('pago_cancelado'),
    }, {idempotencyKey: `appointment-${apptRef.id}`});
    await apptRef.update({checkoutSessionId: session.id});
    return {appointmentId: apptRef.id, checkoutUrl: session.url};
  } catch (err) {
    // Si Stripe falla, se libera el horario.
    logger.error('startBooking: Stripe falló', {appointmentId: apptRef.id, message: err.message});
    await apptRef.update({status: 'expirada'});
    await busyRef(businessId, apptRef.id).delete();
    if (err instanceof HttpsError) throw err;
    fail('unavailable', 'No se pudo iniciar el pago. Inténtalo de nuevo.');
  }
}));

// ---------------------------------------------------------------------------
// Comprar un producto
// ---------------------------------------------------------------------------
exports.startOrder = onCall(callOptions, safe('startOrder', async (request) => {
  const user = requireAuth(request);
  await rateLimit(user.uid, 'order', 10);
  const data = request.data || {};
  const businessId = readId(data.businessId, 'negocio');
  const itemId = readId(data.itemId, 'producto');
  const quantity = data.quantity;
  if (!Number.isInteger(quantity) || quantity < 1 || quantity > MAX_QUANTITY) {
    fail('invalid-argument', `La cantidad debe ser de 1 a ${MAX_QUANTITY}.`);
  }

  const business = await getBusiness(businessId);
  if (business.demo === true) fail('failed-precondition', 'Los negocios de ejemplo no venden en línea.');
  const account = await requirePayableBusiness(businessId);
  const itemRef = db.collection('businesses').doc(businessId).collection('items').doc(itemId);
  const orderRef = db.collection('orders').doc();
  const now = Date.now();
  const expiresAtSec = Math.floor(now / 1000) + CHECKOUT_MINUTES * 60;
  let order;

  // Se apartan las piezas en una transacción para no vender de más.
  await db.runTransaction(async (tx) => {
    const itemSnap = await tx.get(itemRef);
    if (!itemSnap.exists) fail('not-found', 'Ese producto ya no existe.');
    const item = itemSnap.data();
    if (item.kind !== 'producto' || item.active === false) fail('failed-precondition', 'Ese producto no está disponible.');
    const price = readPrice(item.price);
    const stock = Number.isInteger(item.stock) ? item.stock : 0;
    if (stock < quantity) fail('failed-precondition', stock > 0 ? `Solo quedan ${stock} piezas.` : 'Producto agotado.');
    const totalCents = cents(price) * quantity;
    if (totalCents < MIN_CHARGE_CENTS) fail('failed-precondition', 'El total es menor al mínimo de $10 MXN.');
    order = {
      businessId,
      businessName: business.name || '',
      ownerEmail: business.ownerEmail || '',
      itemId,
      itemName: item.name || 'Producto',
      unitPrice: price,
      quantity,
      totalCents,
      buyerUid: user.uid,
      buyerEmail: user.email,
      buyerName: user.name,
      status: 'pendiente_pago',
      holdExpiresAt: Timestamp.fromMillis((expiresAtSec + 120) * 1000),
      createdAt: FieldValue.serverTimestamp(),
    };
    tx.update(itemRef, {stock: FieldValue.increment(-quantity)});
    tx.set(orderRef, order);
  });

  try {
    const customerId = await ensureCustomer(user);
    const session = await stripe().checkout.sessions.create({
      mode: 'payment',
      customer: customerId,
      allowed_payment_method_types: ['card'],
      client_reference_id: orderRef.id,
      line_items: [{
        quantity,
        price_data: {
          currency: CURRENCY,
          unit_amount: cents(order.unitPrice),
          product_data: {name: order.itemName, description: `${order.businessName} · se recoge en el negocio`},
        },
      }],
      payment_intent_data: {
        ...transferFor(account, order.totalCents),
        description: `Compra Bookly · ${order.businessName}`,
        metadata: {kind: 'order', refId: orderRef.id, uid: user.uid},
      },
      metadata: {kind: 'order', refId: orderRef.id, uid: user.uid},
      saved_payment_method_options: {payment_method_save: 'enabled'},
      expires_at: expiresAtSec,
      success_url: returnUrl('pago_ok'),
      cancel_url: returnUrl('pago_cancelado'),
    }, {idempotencyKey: `order-${orderRef.id}`});
    await orderRef.update({checkoutSessionId: session.id});
    return {orderId: orderRef.id, checkoutUrl: session.url};
  } catch (err) {
    logger.error('startOrder: Stripe falló', {orderId: orderRef.id, message: err.message});
    await releaseOrder(orderRef.id);
    if (err instanceof HttpsError) throw err;
    fail('unavailable', 'No se pudo iniciar el pago. Inténtalo de nuevo.');
  }
}));

/** Regresa las piezas apartadas de un pedido que no se pagó. */
async function releaseOrder(orderId) {
  const ref = db.collection('orders').doc(orderId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists || snap.data().status !== 'pendiente_pago') return;
    const o = snap.data();
    const itemRef = db.collection('businesses').doc(o.businessId).collection('items').doc(o.itemId);
    const itemSnap = await tx.get(itemRef);
    if (itemSnap.exists) tx.update(itemRef, {stock: FieldValue.increment(o.quantity)});
    tx.update(ref, {status: 'expirada'});
  });
}

/** Libera el horario de una cita que no se pagó. */
async function releaseAppointment(appointmentId) {
  const ref = db.collection('appointments').doc(appointmentId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists || snap.data().status !== 'pendiente_pago') return;
    tx.update(ref, {status: 'expirada'});
    tx.delete(busyRef(snap.data().businessId, appointmentId));
  });
}

// ---------------------------------------------------------------------------
// Cancelar un pago que se quedó a medias
// ---------------------------------------------------------------------------
exports.cancelPending = onCall(callOptions, safe('cancelPending', async (request) => {
  const user = requireAuth(request);
  await rateLimit(user.uid, 'cancelPending', 20);
  const data = request.data || {};
  const kind = data.kind === 'order' ? 'order' : 'appointment';
  const id = readId(data.id, 'pago');
  const ref = db.collection(kind === 'order' ? 'orders' : 'appointments').doc(id);
  const snap = await ref.get();
  if (!snap.exists) fail('not-found', 'No se encontró el pago.');
  const doc = snap.data();
  const owner = kind === 'order' ? doc.buyerUid : doc.clientUid;
  if (owner !== user.uid) fail('permission-denied', 'No puedes cancelar este pago.');
  if (doc.status !== 'pendiente_pago') return {status: doc.status};

  if (doc.checkoutSessionId) {
    const session = await stripe().checkout.sessions.retrieve(doc.checkoutSessionId);
    if (session.status === 'complete') return {status: 'procesando'}; // ya pagó: el webhook lo confirma
    if (session.status === 'open') await stripe().checkout.sessions.expire(session.id);
  }
  if (kind === 'order') await releaseOrder(id);
  else await releaseAppointment(id);
  return {status: 'expirada'};
}));

// ---------------------------------------------------------------------------
// Cancelar una cita (con reembolso cuando aplica)
// ---------------------------------------------------------------------------
exports.cancelAppointment = onCall(callOptions, safe('cancelAppointment', async (request) => {
  const user = requireAuth(request);
  await rateLimit(user.uid, 'cancel', 20);
  const id = readId((request.data || {}).appointmentId, 'cita');
  const ref = db.collection('appointments').doc(id);
  const snap = await ref.get();
  if (!snap.exists) fail('not-found', 'La cita no existe.');
  const a = snap.data();
  const isBusiness = a.businessId === user.uid;
  const isClient = a.clientUid === user.uid || (a.clientEmail && a.clientEmail === user.email);
  if (!isBusiness && !isClient) fail('permission-denied', 'No puedes cancelar esta cita.');
  if (a.status !== 'confirmada') fail('failed-precondition', 'Esta cita ya no está activa.');

  const startMs = a.start.toMillis();
  const paidCents = a.paymentIntentId ? cents(a.depositPaid || 0) : 0;
  // El negocio siempre reembolsa; el cliente, solo con 24 h de anticipación.
  const refundable = paidCents > 0 && (isBusiness || startMs - Date.now() >= 24 * 3600000);
  let refundId = null;
  if (refundable) {
    const refund = await refundPayment(
      a.paymentIntentId,
      {kind: 'appointment', refId: id},
      `refund-appointment-${id}`,
    );
    refundId = refund.id;
  }

  await db.runTransaction(async (tx) => {
    const fresh = await tx.get(ref);
    if (fresh.data().status !== 'confirmada') return;
    tx.update(ref, {
      status: 'cancelada',
      cancelledBy: isBusiness ? 'negocio' : 'cliente',
      cancelledAt: FieldValue.serverTimestamp(),
      refundId,
      refundedCents: refundable ? paidCents : 0,
    });
    tx.delete(busyRef(a.businessId, id));
    if (refundable && a.clientUid) {
      addMovement(tx, `users/${a.clientUid}/movements`, {
        type: 'reembolso', concept: `Reembolso · ${a.serviceName}`, businessName: a.businessName,
        amountCents: paidCents, refId: id,
      });
    }
    if (refundable) {
      addMovement(tx, `businesses/${a.businessId}/movements`, {
        type: 'reembolso', concept: `Reembolso a ${a.clientName} · ${a.serviceName}`,
        grossCents: -paidCents, feeCents: -feeFor(paidCents), netCents: -(paidCents - feeFor(paidCents)), refId: id,
      });
    }
  });
  return {refunded: refundable, amountCents: refundable ? paidCents : 0};
}));

// ---------------------------------------------------------------------------
// Reprogramar una cita
// ---------------------------------------------------------------------------
exports.rescheduleAppointment = onCall(callOptions, safe('rescheduleAppointment', async (request) => {
  const user = requireAuth(request);
  await rateLimit(user.uid, 'reschedule', 10);
  const data = request.data || {};
  const id = readId(data.appointmentId, 'cita');
  const startMs = readStart(data.start);
  const preferred = readOptionalName(data.professional, 'profesional');
  const ref = db.collection('appointments').doc(id);

  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) fail('not-found', 'La cita no existe.');
    const a = snap.data();
    const isBusiness = a.businessId === user.uid;
    const isClient = a.clientUid === user.uid || (a.clientEmail && a.clientEmail === user.email);
    if (!isBusiness && !isClient) fail('permission-denied', 'No puedes cambiar esta cita.');
    if (a.status !== 'confirmada') fail('failed-precondition', 'Esta cita ya no está activa.');
    const bizSnap = await tx.get(db.collection('businesses').doc(a.businessId));
    if (!bizSnap.exists) fail('not-found', 'El negocio ya no existe.');
    const business = bizSnap.data();
    const hours = checkBusinessHours(business, startMs, a.minutes);
    if (!hours.ok) fail('failed-precondition', hours.reason);
    const existing = await dayAppointments(tx, a.businessId, hours.local.dayKey);
    const pro = pickProfessional({
      business, startMs, minutes: a.minutes, existing, preferred, ignoreId: id, nowMs: Date.now(),
    });
    if (!pro) fail('aborted', 'Ese horario ya no está disponible. Elige otro.');
    const update = {start: Timestamp.fromMillis(startMs), day: hours.local.dayKey, professional: pro};
    tx.update(ref, update);
    tx.set(busyRef(a.businessId, id), busyData({...a, ...update}));
    return {professional: pro, start: startMs};
  });
  return result;
}));

// ---------------------------------------------------------------------------
// El negocio agrega a una persona a su agenda
// ---------------------------------------------------------------------------
exports.addManualAppointment = onCall(callOptions, safe('addManualAppointment', async (request) => {
  const user = requireAuth(request);
  await rateLimit(user.uid, 'manual', 30);
  const data = request.data || {};
  const businessId = user.uid; // solo puede agendar en SU negocio
  const itemId = readId(data.itemId, 'servicio');
  const startMs = readStart(data.start);
  const preferred = readOptionalName(data.professional, 'profesional');
  const clientName = readText(data.clientName, 'nombre', {max: 80, required: true});
  const clientEmail = readEmail(data.clientEmail);
  const clientPhone = readPhone(data.clientPhone);
  const note = readText(data.note, 'nota', {max: 300});

  const [business, item] = await Promise.all([getBusiness(businessId), getItem(businessId, itemId)]);
  if (item.kind !== 'servicio') fail('failed-precondition', 'Solo los servicios se pueden agendar.');
  const price = readPrice(item.price);
  const deposit = Number(data.depositPaid || 0);
  if (!Number.isFinite(deposit) || deposit < 0 || deposit > price) {
    fail('invalid-argument', 'El anticipo debe estar entre $0 y el precio del servicio.');
  }
  const minutes = Number.isInteger(item.minutes) && item.minutes >= 15 && item.minutes <= 480 ? item.minutes : 60;
  const hours = checkBusinessHours(business, startMs, minutes);
  if (!hours.ok) fail('failed-precondition', hours.reason);

  const ref = db.collection('appointments').doc();
  const now = Date.now();
  const appointment = await db.runTransaction(async (tx) => {
    const existing = await dayAppointments(tx, businessId, hours.local.dayKey);
    const pro = pickProfessional({business, startMs, minutes, existing, preferred, nowMs: now});
    if (!pro) fail('aborted', 'Ese horario ya no está disponible. Elige otro.');
    const appt = {
      businessId,
      businessName: business.name || '',
      ownerEmail: business.ownerEmail || '',
      itemId,
      serviceName: item.name || 'Servicio',
      minutes,
      price,
      depositPaid: Math.round(deposit * 100) / 100,
      amountCents: 0,
      professional: pro,
      start: Timestamp.fromMillis(startMs),
      day: hours.local.dayKey,
      clientUid: null,
      clientName,
      clientEmail,
      clientPhone,
      note,
      status: 'confirmada',
      createdByBusiness: true,
      createdAt: FieldValue.serverTimestamp(),
    };
    tx.set(ref, appt);
    tx.set(busyRef(businessId, ref.id), busyData(appt));
    if (deposit > 0) {
      addMovement(tx, `businesses/${businessId}/movements`, {
        type: 'anticipo_en_local', concept: `Anticipo en el local · ${clientName}`,
        grossCents: cents(deposit), feeCents: 0, netCents: cents(deposit), refId: ref.id,
      });
    }
    return appt;
  });
  return {appointmentId: ref.id, professional: appointment.professional};
}));

// ---------------------------------------------------------------------------
// Billetera del cliente: tarjetas guardadas en Stripe
// ---------------------------------------------------------------------------
exports.walletMethods = onCall(callOptions, safe('walletMethods', async (request) => {
  const user = requireAuth(request);
  await rateLimit(user.uid, 'wallet', 30);
  const customerId = await existingCustomer(user.uid);
  if (!customerId) return {methods: []};
  const list = await stripe().customers.listPaymentMethods(customerId, {type: 'card', limit: 20});
  return {
    methods: list.data.map((pm) => ({
      id: pm.id,
      brand: pm.card ? pm.card.brand : 'card',
      last4: pm.card ? pm.card.last4 : '••••',
      expMonth: pm.card ? pm.card.exp_month : 0,
      expYear: pm.card ? pm.card.exp_year : 0,
    })),
  };
}));

exports.walletSetup = onCall(callOptions, safe('walletSetup', async (request) => {
  const user = requireAuth(request);
  await rateLimit(user.uid, 'walletSetup', 5);
  const customerId = await ensureCustomer(user);
  const session = await stripe().checkout.sessions.create({
    mode: 'setup',
    customer: customerId,
    currency: CURRENCY,
    allowed_payment_method_types: ['card'],
    success_url: returnUrl('tarjeta_ok'),
    cancel_url: returnUrl('tarjeta_cancelada'),
  });
  return {url: session.url};
}));

exports.walletRemoveMethod = onCall(callOptions, safe('walletRemoveMethod', async (request) => {
  const user = requireAuth(request);
  await rateLimit(user.uid, 'walletRemove', 10);
  const pmId = (request.data || {}).paymentMethodId;
  if (typeof pmId !== 'string' || !/^pm_[A-Za-z0-9]{6,64}$/.test(pmId)) fail('invalid-argument', 'Método de pago no válido.');
  const customerId = await existingCustomer(user.uid);
  if (!customerId) fail('not-found', 'No tienes métodos de pago.');
  const pm = await stripe().paymentMethods.retrieve(pmId);
  // Solo se puede borrar una tarjeta propia.
  if (pm.customer !== customerId) fail('permission-denied', 'Ese método de pago no es tuyo.');
  await stripe().paymentMethods.detach(pmId);
  return {ok: true};
}));

// ---------------------------------------------------------------------------
// Cobros del negocio: cuenta de Stripe Connect
// ---------------------------------------------------------------------------
async function requireOwnBusiness(uid) {
  const snap = await db.collection('businesses').doc(uid).get();
  if (!snap.exists) fail('failed-precondition', 'Primero registra tu negocio.');
  return snap.data();
}

/**
 * Cuentas de cobro de los negocios: API v2 de Stripe (accounts v2).
 * La plataforma tiene a Stripe como responsable de pérdidas, así que NO se
 * puede usar el panel Express (dashboard "none"). Los cobros siguen siendo
 * destination charges con el id de la cuenta (acct_...), igual que antes.
 */
exports.connectOnboarding = onCall(callOptions, safe('connectOnboarding', async (request) => {
  const user = requireAuth(request);
  await rateLimit(user.uid, 'connect', 5);
  await requireOwnBusiness(user.uid);
  const ref = db.collection('stripeAccounts').doc(user.uid);
  const stored = await getStoredAccount(user.uid);
  let account = usableAccount(stored);
  if (!account) {
    // Sin cuenta, o con una vieja (API v1): se crea una v2 y se conserva el id viejo.
    const created = await stripe().v2.core.accounts.create({
      contact_email: user.email,
      identity: {country: 'mx'},
      dashboard: 'none',
      defaults: {responsibilities: {fees_collector: 'application', losses_collector: 'stripe'}},
      configuration: {
        merchant: {capabilities: {card_payments: {requested: true}}},
        recipient: {capabilities: {stripe_balance: {stripe_transfers: {requested: true}}}},
      },
      metadata: {uid: user.uid},
    }, {idempotencyKey: `account-v2-${user.uid}`});
    account = {accountId: created.id, chargesEnabled: false, apiVersion: 'v2'};
    const update = {...account, updatedAt: FieldValue.serverTimestamp()};
    if (stored && stored.accountId) update.legacyAccountId = stored.accountId;
    if (!stored) update.createdAt = FieldValue.serverTimestamp();
    await ref.set(update, {merge: true});
  }
  const link = await stripe().v2.core.accountLinks.create({
    account: account.accountId,
    use_case: {
      type: 'account_onboarding',
      account_onboarding: {
        refresh_url: returnUrl('negocio_reintentar'),
        return_url: returnUrl('negocio_ok'),
      },
    },
  });
  return {url: link.url};
}));

/**
 * Lee la cuenta v2 en Stripe, calcula sus capacidades y guarda el estado
 * (stripeAccounts.chargesEnabled). Lo usan connectRefreshStatus y el webhook de Connect.
 */
async function syncConnectStatus(businessId, accountId) {
  const a = await stripe().v2.core.accounts.retrieve(accountId, {
    include: ['configuration.merchant', 'configuration.recipient'],
  });
  const caps = connectCapabilities(a);
  const status = {
    connected: true,
    chargesEnabled: caps.cardPayments,
    payoutsEnabled: caps.transfers,
    // En cuentas v2 no hay "details_submitted": se considera enviado cuando
    // ya están activos el cobro con tarjeta y las transferencias.
    detailsSubmitted: caps.cardPayments && caps.transfers,
  };
  await db.collection('stripeAccounts').doc(businessId).update({chargesEnabled: status.chargesEnabled});
  return status;
}

exports.connectRefreshStatus = onCall(callOptions, safe('connectRefreshStatus', async (request) => {
  const user = requireAuth(request);
  await rateLimit(user.uid, 'connectStatus', 20);
  // Un registro viejo (no v2) cuenta como "sin cuenta": no se llama a la API v2.
  const account = await getConnectedAccount(user.uid);
  const status = {connected: false, chargesEnabled: false, payoutsEnabled: false, detailsSubmitted: false};
  if (!account) {
    const stored = await getStoredAccount(user.uid);
    if (stored && stored.chargesEnabled) {
      await db.collection('stripeAccounts').doc(user.uid).update({chargesEnabled: false});
    }
  } else {
    Object.assign(status, await syncConnectStatus(user.uid, account.accountId));
  }
  // Estado público (sin el id de la cuenta) para que los clientes sepan si pueden pagar.
  await db.collection('paymentStatus').doc(user.uid).set({...status, updatedAt: FieldValue.serverTimestamp()});
  return status;
}));

// Las cuentas v2 no tienen panel Express; se conserva la función solo para
// que versiones viejas de la app reciban un mensaje claro.
exports.connectDashboard = onCall(callOptions, safe('connectDashboard', async (request) => {
  requireAuth(request);
  fail('failed-precondition', 'Stripe ya no ofrece un panel aparte para tu cuenta; consulta tus cobros en Cobros y ventas.');
}));

// ---------------------------------------------------------------------------
// Borrar la cuenta (requisito de Google Play)
// ---------------------------------------------------------------------------
async function deleteQueryInBatches(query) {
  const snap = await query.get();
  for (const group of chunkList(snap.docs, 500)) {
    const batch = db.batch();
    group.forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
  return snap.size;
}

async function anonymizeDocs(docs, patchFor, uid) {
  const items = docs.map((d) => ({ref: d.ref, patch: patchFor(d.data(), uid)})).filter((x) => x.patch);
  for (const group of chunkList(items, 500)) {
    const batch = db.batch();
    group.forEach((x) => batch.update(x.ref, x.patch));
    await batch.commit();
  }
}

exports.deleteAccount = onCall(callOptions, safe('deleteAccount', async (request) => {
  const user = requireAuth(request);
  await rateLimit(user.uid, 'deleteAccount', 3);
  const uid = user.uid;
  if ((request.data || {}).confirm !== 'BORRAR') fail('invalid-argument', 'Escribe BORRAR para confirmar.');

  // 1. ¿Hay algo que impida borrar? (citas por venir o pagos pendientes)
  const [apptClient, apptBiz, ordBuyer, ordBiz] = await Promise.all([
    db.collection('appointments').where('clientUid', '==', uid).get(),
    db.collection('appointments').where('businessId', '==', uid).get(),
    db.collection('orders').where('buyerUid', '==', uid).get(),
    db.collection('orders').where('businessId', '==', uid).get(),
  ]);
  const reasons = blockingReasons({
    uid,
    appointments: [...apptClient.docs, ...apptBiz.docs].map((d) => d.data()),
    orders: [...ordBuyer.docs, ...ordBiz.docs].map((d) => d.data()),
  });
  if (reasons.length) fail('failed-precondition', reasons.join(' '));

  // 2. Historial de otros: se quitan nombre y correo, se conservan montos.
  await anonymizeDocs(apptClient.docs, anonymizeAppointment, uid);
  await anonymizeDocs(ordBuyer.docs, anonymizeOrder, uid);

  // 3. Datos propios (recursiveDelete incluye subcolecciones: movements, items, gallery, busy).
  await db.recursiveDelete(db.collection('users').doc(uid));
  await db.recursiveDelete(db.collection('businesses').doc(uid));
  await deleteQueryInBatches(db.collection('posts').where('businessId', '==', uid));
  await db.collection('paymentStatus').doc(uid).delete();
  try {
    await getStorage().bucket().deleteFiles({prefix: `posts/${uid}/`});
  } catch (err) {
    logger.warn('deleteAccount: no se pudieron borrar los videos', {uid, message: err && err.message});
  }

  // 4. Stripe: se borra el cliente (tarjetas guardadas). La cuenta Connect NO se
  // elimina desde aquí (puede tener saldo); solo se quita el vínculo y se deja en el registro.
  const customerId = await existingCustomer(uid);
  if (customerId) {
    try {
      await stripe().customers.del(customerId);
    } catch (err) {
      logger.warn('deleteAccount: no se pudo borrar el cliente de Stripe', {customerId, message: err && err.message});
    }
  }
  await db.collection('stripeCustomers').doc(uid).delete();
  const account = await getStoredAccount(uid);
  if (account) {
    logger.info('deleteAccount: cuenta Connect desvinculada (cerrar a mano en Stripe si hace falta)', {
      accountId: account.accountId || account.id || null,
    });
  }
  await db.collection('stripeAccounts').doc(uid).delete();

  // 5. Al final, el usuario de Firebase Auth.
  await getAuth().deleteUser(uid);
  return {deleted: true};
}));

// ---------------------------------------------------------------------------
// Webhook: Stripe avisa cuando un pago se completó o venció
// ---------------------------------------------------------------------------
exports.stripeWebhook = onRequest(
  {secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET], memory: '256MiB'},
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).send('Method not allowed');
      return;
    }
    let event;
    try {
      // Si la firma no coincide, alguien está intentando falsificar un pago.
      event = stripe().webhooks.constructEvent(
        req.rawBody,
        req.get('stripe-signature'),
        STRIPE_WEBHOOK_SECRET.value(),
      );
    } catch (err) {
      logger.warn('Webhook con firma inválida', {message: err.message});
      res.status(400).send('Invalid signature');
      return;
    }

    // Cada evento se procesa una sola vez.
    const eventRef = db.collection('stripeEvents').doc(event.id);
    try {
      await eventRef.create({type: event.type, receivedAt: FieldValue.serverTimestamp()});
    } catch (_) {
      res.json({received: true, duplicate: true});
      return;
    }

    try {
      const session = event.data.object;
      if (event.type === 'checkout.session.completed' && session.mode === 'payment' && session.payment_status === 'paid') {
        await handlePaid(session);
      } else if (event.type === 'checkout.session.expired' && session.mode === 'payment') {
        const kind = session.metadata && session.metadata.kind;
        const refId = session.metadata && session.metadata.refId;
        if (kind === 'order' && refId) await releaseOrder(refId);
        if (kind === 'appointment' && refId) await releaseAppointment(refId);
      }
      res.json({received: true});
    } catch (err) {
      logger.error('Error procesando webhook', {type: event.type, message: err.message});
      await eventRef.delete(); // para que Stripe lo reintente
      res.status(500).send('Error');
    }
  },
);

// ---------------------------------------------------------------------------
// Webhook de Connect (avisos "thin" v2): actualiza solo el estado de cobro.
// PENDIENTE DE VERIFICAR en la sandbox (ver PAGOS_STRIPE.md).
// ---------------------------------------------------------------------------
exports.stripeConnectWebhook = onRequest(
  {secrets: [STRIPE_SECRET_KEY, STRIPE_CONNECT_WEBHOOK_SECRET], memory: '256MiB'},
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).send('Method not allowed');
      return;
    }
    let notification;
    try {
      notification = stripe().parseEventNotification(
        req.rawBody,
        req.get('stripe-signature'),
        STRIPE_CONNECT_WEBHOOK_SECRET.value(),
      );
    } catch (err) {
      logger.warn('Webhook de Connect con firma inválida', {message: err.message});
      res.status(400).send('Invalid signature');
      return;
    }

    const decision = decideNotification(notification);
    if (!decision.process) {
      res.json({received: true, ignored: decision.reason});
      return;
    }

    // Cada evento se procesa una sola vez.
    const eventRef = db.collection('stripeEvents').doc(notification.id);
    try {
      await eventRef.create({type: notification.type, receivedAt: FieldValue.serverTimestamp()});
    } catch (_) {
      res.json({received: true, duplicate: true});
      return;
    }

    try {
      const found = await db.collection('stripeAccounts')
        .where('accountId', '==', decision.accountId).limit(1).get();
      const doc = found.docs[0];
      if (!doc || !usableAccount(doc.data())) {
        // Cuenta que no es de ningún negocio de Bookly: nada que actualizar.
        res.json({received: true, unknownAccount: true});
        return;
      }
      const status = await syncConnectStatus(doc.id, decision.accountId);
      await db.collection('paymentStatus').doc(doc.id).set({...status, updatedAt: FieldValue.serverTimestamp()});
      res.json({received: true});
    } catch (err) {
      logger.error('Error procesando webhook de Connect', {type: notification.type, message: err.message});
      await eventRef.delete(); // para que Stripe lo reintente
      res.status(500).send('Error');
    }
  },
);

async function handlePaid(session) {
  const kind = session.metadata && session.metadata.kind;
  const refId = session.metadata && session.metadata.refId;
  if (!refId || !ID_PATTERN.test(refId)) return;
  const paymentIntentId = typeof session.payment_intent === 'string'
    ? session.payment_intent
    : session.payment_intent && session.payment_intent.id;
  const paid = session.amount_total || 0;
  const collection = kind === 'order' ? 'orders' : 'appointments';
  const ref = db.collection(collection).doc(refId);

  const outcome = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return 'missing';
    const doc = snap.data();
    if (doc.status !== 'pendiente_pago') return doc.status === 'confirmada' || doc.status === 'pagada' ? 'done' : 'late';
    const expected = kind === 'order' ? doc.totalCents : doc.amountCents;
    if (paid !== expected) {
      logger.error('Monto pagado distinto al esperado', {refId, paid, expected});
      return 'mismatch';
    }
    const fee = feeFor(paid);
    if (kind === 'order') {
      tx.update(ref, {status: 'pagada', paymentIntentId, paidAt: FieldValue.serverTimestamp()});
      addMovement(tx, `users/${doc.buyerUid}/movements`, {
        type: 'compra', concept: `${doc.quantity} × ${doc.itemName}`, businessName: doc.businessName,
        amountCents: paid, refId,
      });
      addMovement(tx, `businesses/${doc.businessId}/movements`, {
        type: 'venta', concept: `Venta a ${doc.buyerName} · ${doc.quantity} × ${doc.itemName}`,
        grossCents: paid, feeCents: fee, netCents: paid - fee, refId,
      });
    } else {
      tx.update(ref, {
        status: 'confirmada',
        depositPaid: paid / 100,
        paymentIntentId,
        paidAt: FieldValue.serverTimestamp(),
        holdExpiresAt: null,
      });
      tx.set(busyRef(doc.businessId, refId), {status: 'confirmada', holdExpiresAt: null}, {merge: true});
      addMovement(tx, `users/${doc.clientUid}/movements`, {
        type: 'anticipo', concept: `Anticipo · ${doc.serviceName}`, businessName: doc.businessName,
        amountCents: paid, refId,
      });
      addMovement(tx, `businesses/${doc.businessId}/movements`, {
        type: 'anticipo', concept: `Anticipo de ${doc.clientName} · ${doc.serviceName}`,
        grossCents: paid, feeCents: fee, netCents: paid - fee, refId,
      });
    }
    return 'ok';
  });

  // Pagó tarde (ya había vencido) o el monto no cuadra: se devuelve el dinero.
  if ((outcome === 'late' || outcome === 'mismatch') && paymentIntentId) {
    await refundPayment(
      paymentIntentId,
      {kind: kind || '', refId, reason: outcome},
      `refund-${outcome}-${refId}`,
    );
    await ref.update({status: 'reembolsada', paymentIntentId});
  }
}

// ---------------------------------------------------------------------------
// Página a la que regresa la persona después de usar Stripe
// ---------------------------------------------------------------------------
const RETURN_MESSAGES = {
  pago_ok: ['✅ Pago recibido', 'Regresa a Bookly: tu reservación o compra se confirma en unos segundos.'],
  pago_cancelado: ['Pago cancelado', 'No se hizo ningún cargo. Regresa a Bookly para intentarlo de nuevo.'],
  tarjeta_ok: ['✅ Tarjeta guardada', 'Regresa a Bookly y toca "Actualizar" en tu billetera.'],
  tarjeta_cancelada: ['Sin cambios', 'No se guardó ninguna tarjeta. Puedes regresar a Bookly.'],
  negocio_ok: ['✅ Datos enviados', 'Regresa a Bookly y toca "Actualizar estado" en Cobros.'],
  negocio_reintentar: ['El enlace venció', 'Regresa a Bookly y toca "Conectar cuenta" otra vez.'],
};

exports.returnPage = onRequest({memory: '128MiB'}, (req, res) => {
  const key = typeof req.query.s === 'string' && RETURN_MESSAGES[req.query.s] ? req.query.s : 'pago_cancelado';
  const [title, text] = RETURN_MESSAGES[key];
  res.set('Content-Type', 'text/html; charset=utf-8');
  res.set('Cache-Control', 'no-store');
  res.set('X-Content-Type-Options', 'nosniff');
  res.set('X-Frame-Options', 'DENY');
  res.set('Content-Security-Policy', "default-src 'none'; style-src 'unsafe-inline'");
  res.send(`<!doctype html><html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Bookly</title>
<style>body{font-family:system-ui,sans-serif;background:#EEF2F3;color:#1D2A30;display:flex;min-height:100vh;align-items:center;justify-content:center;margin:0;padding:16px}
.c{background:#fff;border-radius:16px;padding:28px;max-width:420px;text-align:center;box-shadow:0 2px 8px rgba(15,68,80,.1)}
h1{color:#1C6470;font-size:22px}p{line-height:1.5}</style></head>
<body><div class="c"><h1>${title}</h1><p>${text}</p><p>Ya puedes cerrar esta ventana.</p></div></body></html>`);
});
