import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/database.dart';
import '../services/email_service.dart';
import '../services/payments_service.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

/// Pantalla que espera la confirmación del pago.
///
/// La persona paga en la página de Stripe (fuera de la app). Stripe le
/// avisa al servidor (webhook) y el servidor cambia el estado de la cita o
/// del pedido; esta pantalla lo escucha en vivo y se actualiza sola.
/// La app nunca "decide" que se pagó: solo muestra lo que dice el servidor.
class CheckoutWaitScreen extends StatefulWidget {
  const CheckoutWaitScreen({
    super.key,
    required this.id,
    required this.isOrder,
    this.checkoutUrl,
  });

  final String id;
  final bool isOrder;
  final String? checkoutUrl;

  @override
  State<CheckoutWaitScreen> createState() => _CheckoutWaitScreenState();
}

class _CheckoutWaitScreenState extends State<CheckoutWaitScreen> {
  late final Stream<Appointment?> _appointment =
      Database.instance.appointmentStream(widget.id);
  late final Stream<ShopOrder?> _order = Database.instance.orderStream(widget.id);
  bool _emailSent = false;
  bool _busy = false;

  Future<void> _reopen() async {
    final url = widget.checkoutUrl;
    if (url == null) return;
    try {
      await Payments.openStripePage(url);
    } on PaymentException catch (e) {
      if (mounted) showMessage(context, e.message);
    }
  }

  Future<void> _cancel() async {
    final ok = await confirmDialog(
      context,
      title: '¿Cancelar el pago?',
      message: widget.isOrder
          ? 'Las piezas apartadas regresan al inventario del negocio.'
          : 'El horario apartado se libera para otras personas.',
      confirmLabel: 'Cancelar pago',
      color: AppColors.red,
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      final status = await Payments.cancelPending(isOrder: widget.isOrder, id: widget.id);
      if (mounted && status == 'procesando') {
        showMessage(context, 'Tu pago ya se hizo; estamos esperando la confirmación.');
      }
    } on PaymentException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _finish() {
    final session = AppScope.read(context);
    if (!widget.isOrder) session.clientTab = 2; // "Mis citas"
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Aviso por correo al negocio, una sola vez y solo cuando el servidor
  /// ya confirmó el pago.
  void _notifyOnce(Appointment a) {
    if (_emailSent) return;
    _emailSent = true;
    EmailService.notifyNewBooking(a);
  }

  void _notifyOrderOnce(ShopOrder o) {
    if (_emailSent) return;
    _emailSent = true;
    EmailService.notifyNewOrder(o);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isOrder ? 'Tu compra' : 'Tu reserva'),
          leading: IconButton(icon: const Icon(Icons.close), onPressed: _finish),
        ),
        body: widget.isOrder
            ? StreamBuilder<ShopOrder?>(
                stream: _order,
                builder: (context, snap) {
                  final o = snap.data;
                  if (o == null) return _waiting(snap.hasError);
                  if (o.isPaid) _notifyOrderOnce(o);
                  return _forStatus(
                    o.status,
                    paidTitle: '¡Compra pagada!',
                    paidText: '${o.quantity} × ${o.itemName}\n${o.businessName}\n\n'
                        'Total pagado: ${money2(fromCents(o.totalCents))}\n'
                        'Pasa a recogerlo al negocio.',
                  );
                },
              )
            : StreamBuilder<Appointment?>(
                stream: _appointment,
                builder: (context, snap) {
                  final a = snap.data;
                  if (a == null) return _waiting(snap.hasError);
                  if (a.status == AppointmentStatus.confirmada) _notifyOnce(a);
                  return _forStatus(
                    a.status == AppointmentStatus.confirmada ? 'pagada' : a.status.wire,
                    paidTitle: '¡Cita confirmada!',
                    paidText: '${a.serviceName} en ${a.businessName}\n'
                        '${shortDate(a.start)} · ${hhmm(a.start)} con ${a.professional}\n\n'
                        '${a.depositPaid > 0 ? 'Anticipo pagado: ${money2(a.depositPaid)}\n' : ''}'
                        'Pagarás ${money2(a.remaining)} en el negocio.',
                  );
                },
              ),
      ),
    );
  }

  Widget _waiting(bool error) => Center(
        child: error
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No se pudo leer el estado del pago. Revisa tu conexión.'),
              )
            : const CircularProgressIndicator(),
      );

  Widget _forStatus(String status, {required String paidTitle, required String paidText}) {
    switch (status) {
      case 'pagada':
        return _result(
          icon: Icons.check_circle,
          color: AppColors.green,
          title: paidTitle,
          text: paidText,
        );
      case 'reembolsada':
        return _result(
          icon: Icons.replay_circle_filled_outlined,
          color: AppColors.amber,
          title: 'Pago devuelto',
          text: 'El pago llegó cuando el apartado ya había vencido (o el monto no '
              'coincidía), así que se te reembolsó completo. Puedes intentarlo de nuevo.',
        );
      case 'expirada':
      case 'cancelada':
        return _result(
          icon: Icons.cancel_outlined,
          color: AppColors.red,
          title: 'Pago no completado',
          text: 'No se hizo ningún cargo. '
              '${widget.isOrder ? 'Las piezas' : 'El horario'} quedó libre otra vez.',
        );
    }
    // pendiente_pago
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 20),
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 24),
        const Text(
          'Esperando la confirmación del pago…',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          'Completa el pago en la página segura de Stripe que se abrió. '
          'En cuanto Stripe lo confirme, esta pantalla cambiará sola.\n\n'
          '${widget.isOrder ? 'Tus piezas están apartadas' : 'Tu horario está apartado'} '
          'por 30 minutos.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 24),
        if (widget.checkoutUrl != null)
          PrimaryButton(label: 'Abrir otra vez la página de pago', onPressed: _reopen),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: _busy ? null : _cancel,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.red,
            side: const BorderSide(color: Color(0xFFE8B4B4)),
          ),
          child: const Text('Cancelar pago'),
        ),
        const SizedBox(height: 20),
        const AppCard(
          color: AppColors.mist,
          child: Text(
            'Modo de prueba: usa la tarjeta 4242 4242 4242 4242, cualquier fecha '
            'futura y cualquier CVV. Con 4000 0000 0000 0002 el banco la rechaza.',
            style: TextStyle(fontSize: 12, color: AppColors.deep),
          ),
        ),
      ],
    );
  }

  Widget _result({
    required IconData icon,
    required Color color,
    required String title,
    required String text,
  }) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 20),
        Icon(icon, color: color, size: 72),
        const SizedBox(height: 16),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text(text, textAlign: TextAlign.center),
        const SizedBox(height: 28),
        PrimaryButton(label: widget.isOrder ? 'Listo' : 'Ver mis citas', onPressed: _finish),
      ],
    );
  }
}
