import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/database.dart';
import '../services/email_service.dart';
import '../services/payments_service.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'checkout_wait_screen.dart';

/// Pantalla 3.7: Pago del anticipo (25 %).
///
/// Seguridad:
///  - La app NO pide ni ve los datos de la tarjeta: el pago se hace en la
///    página segura de Stripe (modo de prueba).
///  - El monto lo calcula el SERVIDOR con el precio guardado en la base de
///    datos; aunque alguien modifique la app no puede pagar menos.
///  - El servidor vuelve a revisar que el horario siga libre y lo aparta
///    30 minutos mientras se paga.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.business,
    required this.service,
    required this.start,
    this.preferred,
    this.note = '',
  });

  final Business business;
  final Item service;
  final DateTime start;
  final String? preferred; // quién atiende (elegido con el horario)
  final String note;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late final Stream<PayoutStatus> _payout =
      Database.instance.payoutStatusStream(widget.business.id);
  bool _paying = false;

  bool get _isDemo => widget.business.demo;

  Future<void> _pay() async {
    setState(() => _paying = true);
    try {
      final start = await Payments.startBooking(
        businessId: widget.business.id,
        itemId: widget.service.id,
        start: widget.start,
        professional: widget.preferred,
        note: widget.note,
      );
      if (!mounted) return;

      if (start.demo) {
        await _demoConfirmed(start.id);
        return;
      }
      final url = start.checkoutUrl;
      if (url == null) throw PaymentException('No se pudo abrir la página de pago.');
      await Payments.openStripePage(url);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CheckoutWaitScreen(id: start.id, isOrder: false, checkoutUrl: url),
        ),
      );
    } on PaymentException catch (e) {
      if (!mounted) return;
      await showInfoDialog(
        context,
        title: 'No se pudo reservar',
        message: e.message,
        icon: Icons.event_busy,
        color: AppColors.amber,
      );
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  /// Los negocios de ejemplo no cobran: el servidor confirma directo.
  Future<void> _demoConfirmed(String appointmentId) async {
    final a = await Database.instance.appointmentStream(appointmentId).first;
    if (a != null) await EmailService.notifyNewBooking(a);
    if (!mounted) return;
    await showInfoDialog(
      context,
      title: '¡Cita confirmada!',
      message: '${widget.service.name} en ${widget.business.name}\n'
          '${shortDate(widget.start)} · ${hhmm(widget.start)}'
          '${a != null ? ' con ${a.professional}' : ''}\n\n'
          'Este es un negocio de ejemplo, así que no se cobró anticipo.',
      icon: Icons.check_circle,
      color: AppColors.green,
    );
    if (!mounted) return;
    AppScope.read(context).clientTab = 2;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Widget _row(String label, String value, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: strong ? AppColors.ink : AppColors.muted,
                    fontSize: strong ? 14 : 13)),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: strong ? AppColors.teal : AppColors.muted,
              fontSize: strong ? 18 : 13,
              fontWeight: strong ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.service;
    final deposit = s.deposit;

    return StreamBuilder<PayoutStatus>(
      stream: _payout,
      builder: (context, snap) {
        final canCharge = _isDemo || (snap.data?.chargesEnabled ?? false);
        final loadingStatus = !_isDemo && !snap.hasData && !snap.hasError;

        return Scaffold(
          appBar: AppBar(title: const Text('Pago del anticipo')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
            children: [
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Resumen de la reserva',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    _row(s.name, money2(s.price)),
                    _row('Negocio', widget.business.name),
                    _row('Fecha', '${shortDate(widget.start)} · ${hhmm(widget.start)}'),
                    _row('Te atiende', widget.preferred ?? 'Cualquiera'),
                    const Divider(height: 24),
                    _row('Anticipo (25 %)', _isDemo ? money2(0) : money2(deposit), strong: true),
                    _row('Restante a pagar en el negocio',
                        money2(s.price - (_isDemo ? 0 : deposit))),
                  ],
                ),
              ),
              const SectionLabel('Cómo se paga'),
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline, color: AppColors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isDemo
                            ? 'Este es un negocio de ejemplo: la cita se confirma sin cobrar.'
                            : 'Se abrirá la página segura de Stripe. Ahí eliges una tarjeta '
                                'guardada o escribes una nueva. Bookly nunca ve los datos '
                                'de tu tarjeta.',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              if (!canCharge && !loadingStatus) ...[
                const SizedBox(height: 10),
                const AppCard(
                  color: AppColors.amberSoft,
                  child: Text(
                    'Este negocio todavía no conecta su cuenta de cobros. En modo de '
                    'prueba el pago se hace igual (lo recibe Bookly) para que puedas probar.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF8A5A0C)),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const AppCard(
                color: AppColors.amberSoft,
                child: Text(
                  'Política de cancelación: puedes cancelar sin costo hasta 24 h '
                  'antes y se te devuelve el anticipo. Después de ese plazo el '
                  'anticipo no es reembolsable.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF8A5A0C)),
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              color: Colors.white,
              child: PrimaryButton(
                label: _isDemo ? 'Confirmar cita' : 'Pagar ${money2(deposit)} con Stripe',
                loading: _paying || loadingStatus,
                onPressed: _pay, // el servidor decide si se puede cobrar
              ),
            ),
          ),
        );
      },
    );
  }
}
