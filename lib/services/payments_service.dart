import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';

/// Error que se muestra tal cual a la persona.
class PaymentException implements Exception {
  PaymentException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Resultado de iniciar un pago.
class CheckoutStart {
  const CheckoutStart({required this.id, this.checkoutUrl, this.demo = false});

  /// Id de la cita o del pedido (para escuchar cuándo se confirma).
  final String id;

  /// Página segura de Stripe. Es null en los negocios de ejemplo.
  final String? checkoutUrl;

  /// Negocio de ejemplo: se confirma sin cobrar.
  final bool demo;
}

/// Todo lo que tiene que ver con DINERO pasa por aquí.
///
/// La app NUNCA escribe pagos ni citas pagadas en la base de datos: llama a
/// las funciones del servidor (carpeta `functions/`), que revisan precios,
/// horarios y permisos, hablan con Stripe y guardan el resultado.
/// Los datos de la tarjeta se escriben solo en la página de Stripe.
class Payments {
  Payments._();

  static FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'us-central1');

  static Future<Map<String, dynamic>> _call(String name, [Map<String, dynamic>? data]) async {
    try {
      final callable = _functions.httpsCallable(
        name,
        options: HttpsCallableOptions(timeout: const Duration(seconds: 40)),
      );
      final result = await callable.call<Object?>(data);
      return _asMap(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw PaymentException(_friendly(e));
    } on PaymentException {
      rethrow;
    } catch (_) {
      throw PaymentException('No hay conexión con el servidor. Revisa tu internet.');
    }
  }

  static Map<String, dynamic> _asMap(Object? v) =>
      v is Map ? v.map((key, value) => MapEntry(key.toString(), value)) : <String, dynamic>{};

  /// Los mensajes del servidor ya vienen en español; los errores internos
  /// se cambian por un mensaje claro (sin detalles técnicos).
  static String _friendly(FirebaseFunctionsException e) {
    final msg = e.message ?? '';
    final technical = msg.isEmpty || msg == msg.toUpperCase() || msg.contains('INTERNAL');
    switch (e.code) {
      case 'not-found' when technical:
        return 'El servidor de pagos todavía no está instalado. '
            'Sigue los pasos de PAGOS_STRIPE.md.';
      case 'internal' || 'unknown':
        return 'Ocurrió un error en el servidor. Inténtalo de nuevo en un momento.';
      case 'unauthenticated':
        return 'Tu sesión expiró. Vuelve a iniciar sesión.';
      case 'deadline-exceeded':
        return 'El servidor tardó demasiado. Inténtalo de nuevo.';
    }
    return technical ? 'No se pudo completar la operación.' : msg;
  }

  /// Solo se abren páginas de Stripe (nunca una dirección que venga de otro lado).
  static Future<void> openStripePage(String url) async {
    final uri = Uri.tryParse(url);
    final trusted = uri != null &&
        uri.scheme == 'https' &&
        (uri.host == 'stripe.com' || uri.host.endsWith('.stripe.com'));
    if (!trusted) throw PaymentException('La dirección de pago no es válida.');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) throw PaymentException('No se pudo abrir la página de pago.');
  }

  static String? _url(Map<String, dynamic> r, String key) {
    final v = r[key];
    return v is String && v.isNotEmpty ? v : null;
  }

  // ------------------------------------------------------------------ Citas

  /// Aparta el horario y regresa la página de pago del anticipo.
  static Future<CheckoutStart> startBooking({
    required String businessId,
    required String itemId,
    required DateTime start,
    String? professional,
    String note = '',
  }) async {
    final r = await _call('startBooking', {
      'businessId': businessId,
      'itemId': itemId,
      'start': start.millisecondsSinceEpoch,
      if (professional != null) 'professional': professional,
      'note': note,
    });
    return CheckoutStart(
      id: r['appointmentId'] as String,
      checkoutUrl: _url(r, 'checkoutUrl'),
      demo: r['demo'] == true,
    );
  }

  /// Cancela una cita confirmada. Regresa cuánto se reembolsó (en pesos).
  static Future<double> cancelAppointment(String appointmentId) async {
    final r = await _call('cancelAppointment', {'appointmentId': appointmentId});
    return r['refunded'] == true ? fromCents(r['amountCents']) : 0;
  }

  /// Cambia la fecha. Regresa quién atiende en el nuevo horario.
  static Future<String> reschedule({
    required String appointmentId,
    required DateTime start,
    String? professional,
  }) async {
    final r = await _call('rescheduleAppointment', {
      'appointmentId': appointmentId,
      'start': start.millisecondsSinceEpoch,
      if (professional != null) 'professional': professional,
    });
    return (r['professional'] as String?) ?? professional ?? '';
  }

  /// El negocio agrega a una persona a su agenda (sin cobro en línea).
  static Future<String> addManualAppointment({
    required String itemId,
    required DateTime start,
    required String clientName,
    String? professional,
    String clientEmail = '',
    String clientPhone = '',
    String note = '',
    double depositPaid = 0,
  }) async {
    final r = await _call('addManualAppointment', {
      'itemId': itemId,
      'start': start.millisecondsSinceEpoch,
      if (professional != null) 'professional': professional,
      'clientName': clientName,
      'clientEmail': clientEmail,
      'clientPhone': clientPhone,
      'note': note,
      'depositPaid': depositPaid,
    });
    return (r['professional'] as String?) ?? professional ?? '';
  }

  // ---------------------------------------------------------------- Pedidos

  static Future<CheckoutStart> startOrder({
    required String businessId,
    required String itemId,
    required int quantity,
  }) async {
    final r = await _call('startOrder', {
      'businessId': businessId,
      'itemId': itemId,
      'quantity': quantity,
    });
    return CheckoutStart(id: r['orderId'] as String, checkoutUrl: _url(r, 'checkoutUrl'));
  }

  /// Cancela un pago que no se terminó (libera el horario o las piezas).
  static Future<String> cancelPending({required bool isOrder, required String id}) async {
    final r = await _call('cancelPending', {'kind': isOrder ? 'order' : 'appointment', 'id': id});
    return (r['status'] as String?) ?? '';
  }

  // --------------------------------------------------------------- Billetera

  static Future<List<SavedCard>> cards() async {
    final r = await _call('walletMethods');
    final list = r['methods'];
    if (list is! List) return const [];
    return [for (final m in list) SavedCard.fromMap(_asMap(m))];
  }

  /// Página de Stripe para guardar una tarjeta nueva.
  static Future<String> addCardUrl() async =>
      _url(await _call('walletSetup'), 'url') ?? (throw PaymentException('No se pudo abrir Stripe.'));

  static Future<void> removeCard(String paymentMethodId) =>
      _call('walletRemoveMethod', {'paymentMethodId': paymentMethodId});

  // -------------------------------------------------------- Cobros (negocio)

  /// Página de Stripe para dar de alta la cuenta donde el negocio recibe su dinero.
  static Future<String> connectUrl() async =>
      _url(await _call('connectOnboarding'), 'url') ?? (throw PaymentException('No se pudo abrir Stripe.'));

  static Future<PayoutStatus> refreshPayoutStatus() async =>
      PayoutStatus.fromMap(await _call('connectRefreshStatus'));
}
