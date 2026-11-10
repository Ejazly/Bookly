import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/database.dart';
import '../services/payments_service.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

/// Billetera del cliente: tarjetas guardadas, pagos y compras.
///
/// Las tarjetas se guardan en Stripe, NO en Bookly. La app solo recibe la
/// marca, los últimos 4 dígitos y el vencimiento para mostrarlos.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with WidgetsBindingObserver {
  late Future<List<SavedCard>> _cards = Payments.cards();
  Stream<List<Movement>>? _movements;
  Stream<List<ShopOrder>>? _orders;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = AppScope.read(context).user?.uid;
    if (uid != null && _movements == null) {
      _movements = Database.instance.userMovements(uid);
      _orders = Database.instance.ordersForBuyer(uid);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Al regresar de la página de Stripe se vuelven a leer las tarjetas.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reload();
  }

  void _reload() {
    if (mounted) setState(() => _cards = Payments.cards());
  }

  Future<void> _addCard() async {
    setState(() => _busy = true);
    try {
      await Payments.openStripePage(await Payments.addCardUrl());
      if (mounted) {
        showMessage(context, 'Cuando termines en Stripe, regresa y toca "Actualizar".');
      }
    } on PaymentException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(SavedCard card) async {
    final ok = await confirmDialog(
      context,
      title: '¿Quitar ${card.brandLabel} •••• ${card.last4}?',
      message: 'Ya no aparecerá al pagar. Puedes volver a agregarla cuando quieras.',
      confirmLabel: 'Quitar',
      color: AppColors.red,
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await Payments.removeCard(card.id);
      _reload();
      if (mounted) showMessage(context, 'Tarjeta eliminada.');
    } on PaymentException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _cardsSection() {
    return FutureBuilder<List<SavedCard>>(
      future: _cards,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          final e = snap.error;
          return AppCard(
            color: AppColors.redSoft,
            child: Text(e is PaymentException ? e.message : 'No se pudieron leer tus tarjetas.',
                style: const TextStyle(color: AppColors.red, fontSize: 13)),
          );
        }
        final cards = snap.data!;
        return AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              if (cards.isEmpty)
                const ListTile(
                  leading: Icon(Icons.credit_card_off_outlined),
                  title: Text('Aún no tienes tarjetas guardadas'),
                  subtitle: Text('También puedes escribir tu tarjeta al momento de pagar.'),
                ),
              for (final c in cards)
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.mist,
                    child: Icon(Icons.credit_card, color: AppColors.teal),
                  ),
                  title: Text('${c.brandLabel} •••• ${c.last4}'),
                  subtitle: Text('Vence ${c.expiryText}'),
                  trailing: IconButton(
                    tooltip: 'Quitar',
                    icon: const Icon(Icons.delete_outline, color: AppColors.red),
                    onPressed: _busy ? null : () => _remove(c),
                  ),
                ),
            ],
          ),
        );
      },
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
            icon: Icons.receipt_long_outlined,
            text: 'Aquí verás tus anticipos, compras y reembolsos.',
          );
        }
        return AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final m in list)
                ListTile(
                  dense: true,
                  leading: Icon(
                    m.isRefund ? Icons.call_received : Icons.call_made,
                    color: m.isRefund ? AppColors.green : AppColors.teal,
                  ),
                  title: Text(m.concept),
                  subtitle: Text([
                    if (m.businessName.isNotEmpty) m.businessName,
                    if (m.createdAt != null) shortDate(m.createdAt!),
                  ].join(' · ')),
                  trailing: Text(
                    '${m.isRefund ? '+' : '−'}${money2(fromCents(m.amountCents))}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: m.isRefund ? AppColors.green : AppColors.ink,
                    ),
                  ),
                ),
            ],
          ),
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
        final list = snap.data!.where((o) => o.status != 'expirada').toList();
        if (list.isEmpty) {
          return const EmptyMessage(
            icon: Icons.shopping_bag_outlined,
            text: 'Aún no compras productos.',
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
                  subtitle: Text(o.businessName),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(money2(fromCents(o.totalCents)),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(o.statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: o.isPaid ? AppColors.green : AppColors.muted,
                          )),
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
      appBar: AppBar(
        title: const Text('Billetera'),
        actions: [
          IconButton(tooltip: 'Actualizar', onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        children: [
          const AppCard(
            color: AppColors.mist,
            child: Row(
              children: [
                Icon(Icons.shield_outlined, color: AppColors.teal),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tus tarjetas las guarda Stripe con cifrado bancario. '
                    'Bookly solo ve la marca y los últimos 4 dígitos.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SectionLabel('Formas de pago'),
          _cardsSection(),
          const SizedBox(height: 10),
          PrimaryButton(
            label: 'Agregar forma de pago',
            loading: _busy,
            onPressed: _addCard,
          ),
          const SectionLabel('Movimientos'),
          _movementsSection(),
          const SectionLabel('Mis compras'),
          _ordersSection(),
        ],
      ),
    );
  }
}
