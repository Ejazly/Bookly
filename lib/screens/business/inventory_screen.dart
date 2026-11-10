import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/database.dart';
import '../../theme/app_colors.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import '../../widgets/images.dart';
import 'item_form_screen.dart';

enum _Filter { todos, servicios, productos }

/// Inventario del negocio: servicios (se agendan) y productos (se venden).
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key, required this.business});

  final Business business;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  late final Stream<List<Item>> _stream = Database.instance.itemsStream(widget.business.id);
  _Filter _filter = _Filter.todos;

  void _open([Item? item]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ItemFormScreen(business: widget.business, existing: item),
      ),
    );
  }

  Future<void> _changeStock(Item item, int delta) async {
    try {
      await Database.instance.changeStock(widget.business.id, item.id, delta);
    } catch (e) {
      if (mounted) showMessage(context, 'No se pudo actualizar: $e');
    }
  }

  Future<void> _toggleActive(Item item, bool active) async {
    try {
      await Database.instance.updateItem(widget.business.id, item.id, {'active': active});
    } catch (e) {
      if (mounted) showMessage(context, 'No se pudo actualizar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventario')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(),
        backgroundColor: AppColors.action,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Agregar servicio o producto'),
      ),
      body: StreamBuilder<List<Item>>(
        stream: _stream,
        builder: (context, snapshot) {
          final status = streamStatus(snapshot);
          if (status != null) return status;
          final all = snapshot.data!;
          final products = all.where((i) => !i.isService).toList();
          final lowStock = products.where((i) => i.stock <= 3).length;
          final list = switch (_filter) {
            _Filter.todos => all,
            _Filter.servicios => all.where((i) => i.isService).toList(),
            _Filter.productos => products,
          };

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 90),
            children: [
              Row(
                children: [
                  _Counter(label: 'Servicios', value: all.length - products.length),
                  const SizedBox(width: 8),
                  _Counter(label: 'Productos', value: products.length),
                  const SizedBox(width: 8),
                  _Counter(
                    label: 'Pocas piezas',
                    value: lowStock,
                    color: lowStock > 0 ? AppColors.amber : AppColors.teal,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SegmentedButton<_Filter>(
                segments: const [
                  ButtonSegment(value: _Filter.todos, label: Text('Todos')),
                  ButtonSegment(value: _Filter.servicios, label: Text('Servicios')),
                  ButtonSegment(value: _Filter.productos, label: Text('Productos')),
                ],
                selected: {_filter},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setState(() => _filter = v.first),
              ),
              const SizedBox(height: 12),
              if (list.isEmpty)
                EmptyMessage(
                  icon: Icons.inventory_2_outlined,
                  text: all.isEmpty
                      ? 'Aún no tienes productos ni servicios.'
                      : 'No hay elementos en este filtro.',
                  action: all.isEmpty
                      ? PrimaryButton(label: 'Agregar el primero', onPressed: () => _open())
                      : null,
                )
              else
                for (final item in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ItemTile(
                      item: item,
                      onTap: () => _open(item),
                      onStock: (d) => _changeStock(item, d),
                      onActive: (v) => _toggleActive(item, v),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.label, required this.value, this.color = AppColors.teal});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$value',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.onTap,
    required this.onStock,
    required this.onActive,
  });

  final Item item;
  final VoidCallback onTap;
  final ValueChanged<int> onStock;
  final ValueChanged<bool> onActive;

  @override
  Widget build(BuildContext context) {
    final i = item;
    final StatusBadge badge;
    if (i.isService) {
      badge = StatusBadge('Servicio · ${durationText(i.minutes)}',
          color: AppColors.teal, background: AppColors.mist);
    } else if (i.stock <= 0) {
      badge = const StatusBadge('Agotado', color: AppColors.red, background: AppColors.redSoft);
    } else if (i.stock <= 3) {
      badge = StatusBadge('Quedan ${i.stock}',
          color: const Color(0xFFB57511), background: AppColors.amberSoft);
    } else {
      badge = StatusBadge('${i.stock} en existencia');
    }

    return Opacity(
      opacity: i.active ? 1 : 0.55,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Base64Image(
              data: i.imageBase64,
              width: 64,
              height: 64,
              placeholderIcon: i.isService ? Icons.content_cut : Icons.shopping_bag_outlined,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(i.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(money2(i.price),
                      style: const TextStyle(
                          color: AppColors.teal, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      badge,
                      if (i.section.isNotEmpty)
                        StatusBadge(i.section, color: AppColors.blue, background: AppColors.mist),
                      if (!i.active)
                        const StatusBadge('Oculto',
                            color: AppColors.muted, background: AppColors.light),
                    ],
                  ),
                ],
              ),
            ),
            if (!i.isService)
              Column(
                children: [
                  IconButton(
                    tooltip: 'Sumar 1',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onStock(1),
                    icon: const Icon(Icons.add_circle_outline, color: AppColors.action),
                  ),
                  IconButton(
                    tooltip: 'Restar 1',
                    visualDensity: VisualDensity.compact,
                    onPressed: i.stock > 0 ? () => onStock(-1) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                ],
              )
            else
              Switch(
                value: i.active,
                activeThumbColor: AppColors.teal,
                onChanged: onActive,
              ),
          ],
        ),
      ),
    );
  }
}
