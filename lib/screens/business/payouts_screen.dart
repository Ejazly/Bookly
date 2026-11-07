import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/database.dart';
import '../../services/payments_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

/// Cobros y ventas del negocio.
///
/// El negocio conecta una cuenta de Stripe (Stripe Connect). Cuando un
/// cliente paga un anticipo o compra un producto, el dinero llega directo a
/// esa cuenta, menos la comisión de Bookly (5 %). Stripe lo deposita al banco
/// del negocio. Bookly nunca guarda la CLABE ni los datos bancarios.
class PayoutsScreen extends StatefulWidget {
  const PayoutsScreen({super.key, required this.business});

  final Business business;

  @override
  State<PayoutsScreen> createState() => _PayoutsScreenState();
}

class _PayoutsScreenState extends State<PayoutsScreen> with WidgetsBindingObserver {
  late final Stream<PayoutStatus> _status =
      Database.instance.payoutStatusStream(widget.business.id);
  late final Stream<List<Movement>> _movements =
      Database.instance.businessMovements(widget.business.id);
  late final Stream<List<ShopOrder>> _orders =
      Database.instance.ordersForBusiness(widget.business.id);
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Al volver de Stripe se revisa si ya quedó activa la cuenta.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh(quiet: true);
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on PaymentException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect() => _run(() async {
        await Payments.openStripePage(await Payments.connectUrl());
      });

  Future<void> _dashboard() => _run(() async {
        await Payments.openStripePage(await Payments.dashboardUrl());
      });

  Future<void> _refresh({bool quiet = false}) async {
    if (_busy) return;
    if (quiet) {
      try {
        await Payments.refreshPayoutStatus();
      } catch (_) {
        // Si falla en segundo plano no se muestra nada.
      }
      return;
    }
    await _run(() async {
      final s = await Payments.refreshPayoutStatus();
      if (mounted) {
        showMessage(
          context,
          s.chargesEnabled ? '¡Listo! Ya puedes recibir pagos.' : 'Stripe todavía revisa tus datos.',
        );
      }
    });
  }

  Widget _statusCard(PayoutStatus s) {
    final IconData icon;
    final Color color;
    final String title;
    final String text;
    if (s.chargesEnabled) {
      icon = Icons.verified;
      color = AppColors.green;
      title = 'Cobros activos';
      text = s.payoutsEnabled
          ? 'Tus clientes ya pueden pagar anticipos y comprar productos. '
              'Stripe deposita tu dinero a tu banco.'
          : 'Ya recibes pagos. Stripe aún revisa tu cuenta bancaria para hacerte depósitos.';
    } else if (s.connected) {
      icon = Icons.hourglass_top;
      color = AppColors.amber;
      title = 'Falta terminar el registro';
      text = 'Continúa en Stripe para completar tus datos. Mientras tanto tus '
          'clientes no pueden pagar en línea.';
    } else {
      icon = Icons.account_balance_outlined;
      color = AppColors.teal;
      title = 'Recibe pagos en línea';
      text = 'Conecta una cuenta de Stripe para recibir los anticipos (25 %) y '
          'las ventas de productos. Bookly cobra una comisión del 5 % por cada pago.';
    }

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 14),
          if (!s.chargesEnabled)
            PrimaryButton(
              label: s.connected ? 'Continuar en Stripe' : 'Conectar con Stripe',
              loading: _busy,
              onPressed: _connect,
            )
          else
            OutlinedButton.icon(
              onPressed: _busy ? null : _dashboard,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Ver saldo y depósitos en Stripe'),
            ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: _busy ? null : () => _refresh(),
            icon: const Icon(Icons.refresh),
            label: const Text('Actualizar estado'),
          ),
        ],
      ),
    );
  }

  Widget _summary(List<Movement> list) {
    final online = list.where((m) => m.type != 'anticipo_en_local');
    final gross = online.fold<int>(0, (s, m) => s + m.grossCents);
    final fee = online.fold<int>(0, (s, m) => s + m.feeCents);
    final net = online.fold<int>(0, (s, m) => s + m.netCents);
    Widget cell(String label, int cents, {Color color = AppColors.ink}) => Expanded(
          child: Column(
            children: [
              Text(money2(fromCents(cents)),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
              Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
            ],
          ),
        );
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Row(
        children: [
          cell('Cobrado', gross),
          cell('Comisión Bookly', fee, color: AppColors.muted),
          cell('Para ti', net, color: AppColors.green),
        ],
      ),
    );
  }

  Widget _movementsSection() {
    return StreamBuilder<List<Movement>>(
      stream: _movements,
      builder: (context, snap) {
        final status = streamStatus(snap);
        if (status != null) return status;
        final list = snap.data!;
        if (list.isEmpty) {
          return const EmptyMessage(
            icon: Icons.payments_outlined,
            text: 'Aquí aparecerán los anticipos y ventas que recibas.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _summary(list),
            const SizedBox(height: 8),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final m in list)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        m.isRefund ? Icons.call_made : Icons.call_received,
                        color: m.isRefund ? AppColors.red : AppColors.green,
                      ),
                      title: Text(m.concept),
                      subtitle: Text([
                        if (m.createdAt != null) '${shortDate(m.createdAt!)} ${hhmm(m.createdAt!)}',
                        if (m.feeCents != 0) 'comisión ${money2(fromCents(m.feeCents.abs()))}',
                        if (m.type == 'anticipo_en_local') 'cobrado en el local',
                      ].join(' · ')),
                      trailing: Text(
                        '${m.netCents < 0 ? '−' : '+'}${money2(fromCents(m.netCents.abs()))}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: m.netCents < 0 ? AppColors.red : AppColors.green,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _ordersSection() {
    return StreamBuilder<List<ShopOrder>>(
      stream: _orders,
      builder: (context, snap) {
        final status = streamStatus(snap);
        if (status != null) return status;
        final list = snap.data!.where((o) => o.isPaid || o.status == 'reembolsada').toList();
        if (list.isEmpty) {
          return const EmptyMessage(
            icon: Icons.shopping_bag_outlined,
            text: 'Aún no vendes productos en línea.',
          );
        }
        return AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final o in list)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.shopping_bag_outlined, color: AppColors.teal),
                  title: Text('${o.quantity} × ${o.itemName}'),
                  subtitle: Text('${o.buyerName} · ${o.buyerEmail}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(money2(fromCents(o.totalCents)),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(o.isPaid ? 'Por entregar' : o.statusLabel,
                          style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cobros y ventas')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        children: [
          StreamBuilder<PayoutStatus>(
            stream: _status,
            builder: (context, snap) => snap.hasData
                ? _statusCard(snap.data!)
                : const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  ),
          ),
          const SectionLabel('Movimientos'),
          _movementsSection(),
          const SectionLabel('Ventas de productos'),
          _ordersSection(),
          const SizedBox(height: 14),
          const Text(
            'Modo de prueba: no se mueve dinero real. En Stripe puedes usar datos '
            'de prueba para llenar el registro.',
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
