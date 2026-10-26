import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

enum _Method { card, mercadoPago }

/// Tarjeta que simula un pago rechazado (igual que las tarjetas de prueba de Stripe).
const String declinedTestCard = '4000000000000002';

/// Pantalla 3.7: Pago del anticipo (25 %).
///
/// En esta versión el pago es SIMULADO: no se cobra nada. Más adelante
/// aquí se conectará Mercado Pago o Stripe en modo de prueba.
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
  final Service service;
  final DateTime start;
  final Professional? preferred;
  final String note;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _holder = TextEditingController();
  final _expiry = TextEditingController();
  final _cvv = TextEditingController();
  _Method _method = _Method.card;
  bool _paying = false;

  @override
  void dispose() {
    _number.dispose();
    _holder.dispose();
    _expiry.dispose();
    _cvv.dispose();
    super.dispose();
  }

  String? _validateNumber(String? v) {
    final digits = (v ?? '').replaceAll(' ', '');
    return RegExp(r'^\d{16}$').hasMatch(digits)
        ? null
        : 'El número debe tener 16 dígitos';
  }

  String? _validateExpiry(String? v) {
    final match = RegExp(r'^(0[1-9]|1[0-2])/(\d{2})$').firstMatch((v ?? '').trim());
    if (match == null) return 'Usa el formato MM/AA';
    final month = int.parse(match.group(1)!);
    final year = 2000 + int.parse(match.group(2)!);
    final now = AppScope.read(context).now;
    // La tarjeta vence al terminar el mes indicado.
    final expires = DateTime(year, month + 1);
    if (!expires.isAfter(now)) return 'La tarjeta está vencida';
    return null;
  }

  Future<void> _pay() async {
    if (_method == _Method.card && !_formKey.currentState!.validate()) return;

    setState(() => _paying = true);
    // Simulamos el tiempo que tarda la pasarela de pago en responder.
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final digits = _number.text.replaceAll(' ', '');
    if (_method == _Method.card && digits == declinedTestCard) {
      setState(() => _paying = false);
      await showInfoDialog(
        context,
        title: 'Pago rechazado',
        message:
            'Tu banco rechazó el cargo, así que la cita NO se agendó. '
            'Intenta con otra tarjeta.',
        icon: Icons.error_outline,
        color: AppColors.red,
      );
      return;
    }

    final state = AppScope.read(context);
    try {
      final a = state.book(
        business: widget.business,
        service: widget.service,
        start: widget.start,
        preferred: widget.preferred,
        note: widget.note,
      );
      setState(() => _paying = false);
      await showInfoDialog(
        context,
        title: '¡Cita confirmada!',
        message: '${a.service.name} en ${a.business.name}\n'
            '${shortDate(a.start)} · ${hhmm(a.start)} con ${a.professional.name}\n\n'
            'Anticipo pagado: ${money2(a.depositPaid)}\n'
            'Pagarás ${money2(a.remaining)} en el negocio.',
        icon: Icons.check_circle,
        color: AppColors.green,
      );
      if (!mounted) return;
      // Regresamos al inicio y abrimos la pestaña "Mis citas".
      state.tab = 2;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on BookingException catch (e) {
      setState(() => _paying = false);
      await showInfoDialog(
        context,
        title: 'Horario no disponible',
        message: e.message,
        icon: Icons.event_busy,
        color: AppColors.amber,
      );
    }
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

  Widget _methodTile(_Method method, IconData icon, String title) {
    final selected = _method == method;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: () => setState(() => _method = method),
        borderColor: selected ? AppColors.teal : Colors.transparent,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.teal : AppColors.gray,
            ),
            const SizedBox(width: 10),
            Icon(icon, color: AppColors.blue),
            const SizedBox(width: 10),
            Expanded(child: Text(title)),
          ],
        ),
      ),
    );
  }

  Widget _cardForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _number,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
              LengthLimitingTextInputFormatter(19),
            ],
            decoration: fieldDecoration('Número de tarjeta',
                icon: Icons.credit_card),
            validator: _validateNumber,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _holder,
            textCapitalization: TextCapitalization.words,
            decoration: fieldDecoration('Nombre como aparece en la tarjeta'),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Escribe el nombre' : null,
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _expiry,
                  keyboardType: TextInputType.datetime,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
                    LengthLimitingTextInputFormatter(5),
                  ],
                  decoration: fieldDecoration('MM/AA'),
                  validator: _validateExpiry,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _cvv,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: fieldDecoration('CVV'),
                  validator: (v) => RegExp(r'^\d{3,4}$').hasMatch(v ?? '')
                      ? null
                      : 'CVV inválido',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const AppCard(
            color: Color(0xFFE6F0F2),
            child: Text(
              'Modo de prueba: usa 4242 4242 4242 4242 para un pago aprobado '
              'o 4000 0000 0000 0002 para un pago rechazado. '
              'Cualquier fecha futura y cualquier CVV.',
              style: TextStyle(fontSize: 12, color: AppColors.deep),
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
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                _row(s.name, money2(s.price)),
                _row('Negocio', widget.business.name),
                _row('Fecha',
                    '${shortDate(widget.start)} · ${hhmm(widget.start)}'),
                _row('Profesional', widget.preferred?.name ?? 'Cualquiera'),
                const Divider(height: 24),
                _row('Anticipo (25 %)', money2(deposit), strong: true),
                _row('Restante a pagar en el negocio',
                    money2(s.price - deposit)),
              ],
            ),
          ),
          const SectionLabel('Método de pago'),
          _methodTile(_Method.card, Icons.credit_card,
              'Tarjeta de crédito o débito'),
          _methodTile(_Method.mercadoPago, Icons.account_balance_wallet_outlined,
              'Mercado Pago'),
          const SizedBox(height: 4),
          if (_method == _Method.card)
            _cardForm()
          else
            const AppCard(
              color: Color(0xFFE6F0F2),
              child: Text(
                'Serás dirigida a Mercado Pago para autorizar el cargo. '
                '(En esta versión el pago se simula y siempre se aprueba.)',
                style: TextStyle(fontSize: 12, color: AppColors.deep),
              ),
            ),
          const SizedBox(height: 12),
          const AppCard(
            color: AppColors.amberSoft,
            child: Text(
              'Política de cancelación: puedes cancelar sin costo hasta 24 h '
              'antes. Después de ese plazo el anticipo no es reembolsable.',
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
            label: 'Pagar ${money2(deposit)} y confirmar',
            loading: _paying,
            onPressed: _pay,
          ),
        ),
      ),
    );
  }
}
