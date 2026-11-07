import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/database.dart';
import '../services/payments_service.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/images.dart';
import 'checkout_wait_screen.dart';

/// Comprar un producto de un negocio y pagarlo en línea.
///
/// El total lo calcula el servidor con el precio y las existencias reales;
/// las piezas se apartan mientras se paga y regresan solas si no se paga.
class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key, required this.business, required this.product});

  final Business business;
  final Item product;

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  static const int _maxQuantity = 10; // igual que en el servidor

  late final Stream<PayoutStatus> _payout =
      Database.instance.payoutStatusStream(widget.business.id);
  int _quantity = 1;
  bool _paying = false;

  int get _limit {
    final stock = widget.product.stock;
    if (stock < 1) return 1;
    return stock > _maxQuantity ? _maxQuantity : stock;
  }

  Future<void> _pay() async {
    setState(() => _paying = true);
    try {
      final start = await Payments.startOrder(
        businessId: widget.business.id,
        itemId: widget.product.id,
        quantity: _quantity,
      );
      final url = start.checkoutUrl;
      if (url == null) throw PaymentException('No se pudo abrir la página de pago.');
      await Payments.openStripePage(url);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CheckoutWaitScreen(id: start.id, isOrder: true, checkoutUrl: url),
        ),
      );
    } on PaymentException catch (e) {
      if (!mounted) return;
      await showInfoDialog(
        context,
        title: 'No se pudo comprar',
        message: e.message,
        icon: Icons.remove_shopping_cart_outlined,
        color: AppColors.amber,
      );
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final total = p.price * _quantity;

    return StreamBuilder<PayoutStatus>(
      stream: _payout,
      builder: (context, snap) {
        final canCharge = snap.data?.chargesEnabled ?? false;
        final loading = !snap.hasData && !snap.hasError;
        return Scaffold(
          appBar: AppBar(title: const Text('Comprar')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
            children: [
              AppCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Base64Image(
                      data: p.imageBase64,
                      width: 80,
                      height: 80,
                      placeholderIcon: Icons.shopping_bag_outlined,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(widget.business.name,
                              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                          const SizedBox(height: 6),
                          Text(money2(p.price),
                              style: const TextStyle(
                                  color: AppColors.teal, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SectionLabel('Cantidad'),
              AppCard(
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Expanded(
                      child: Text('$_quantity',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ),
                    IconButton.filledTonal(
                      onPressed: _quantity < _limit ? () => setState(() => _quantity++) : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Disponibles: ${p.stock} · máximo $_maxQuantity por compra',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
              const SizedBox(height: 14),
              const AppCard(
                padding: EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, color: AppColors.green),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Pagas en la página segura de Stripe y recoges tu producto en '
                        'el negocio. Bookly nunca ve los datos de tu tarjeta.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              if (!canCharge && !loading) ...[
                const SizedBox(height: 10),
                const AppCard(
                  color: AppColors.redSoft,
                  child: Text(
                    'Este negocio todavía no activa sus cobros en línea.',
                    style: TextStyle(fontSize: 12, color: AppColors.red),
                  ),
                ),
              ],
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              color: Colors.white,
              child: PrimaryButton(
                label: 'Pagar ${money2(total)} con Stripe',
                loading: _paying || loading,
                onPressed: canCharge ? _pay : null,
              ),
            ),
          ),
        );
      },
    );
  }
}
