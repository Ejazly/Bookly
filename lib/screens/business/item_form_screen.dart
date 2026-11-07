import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../../services/database.dart';
import '../../theme/app_colors.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import '../../widgets/images.dart';

/// Agregar o editar un producto o servicio: precio, descripción e imagen.
class ItemFormScreen extends StatefulWidget {
  const ItemFormScreen({super.key, required this.business, this.existing});

  final Business business;
  final Item? existing; // null = nuevo

  @override
  State<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends State<ItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _description =
      TextEditingController(text: widget.existing?.description ?? '');
  late final TextEditingController _price = TextEditingController(
      text: widget.existing == null ? '' : _priceText(widget.existing!.price));
  late final TextEditingController _stock =
      TextEditingController(text: '${widget.existing?.stock ?? 0}');

  late ItemKind _kind = widget.existing?.kind ?? ItemKind.servicio;
  late int _minutes = widget.existing?.minutes ?? 60;
  late String? _image = widget.existing?.imageBase64;
  late bool _active = widget.existing?.active ?? true;
  bool _saving = false;

  static String _priceText(double p) =>
      p == p.roundToDouble() ? p.toStringAsFixed(0) : p.toStringAsFixed(2);

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _stock.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final item = Item(
      id: widget.existing?.id ?? '',
      kind: _kind,
      name: _name.text.trim(),
      description: _description.text.trim(),
      price: double.parse(_price.text.trim()),
      minutes: _minutes,
      stock: _kind == ItemKind.producto ? int.parse(_stock.text.trim()) : 0,
      imageBase64: _image,
      active: _active,
    );
    setState(() => _saving = true);
    try {
      await Database.instance.saveItem(widget.business.id, item);
      if (!mounted) return;
      showMessage(context, widget.existing == null
          ? (_kind == ItemKind.servicio ? 'Servicio agregado.' : 'Producto agregado.')
          : 'Cambios guardados.');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showMessage(context, 'No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final ok = await confirmDialog(
      context,
      title: '¿Eliminar "${existing.name}"?',
      message: 'Ya no aparecerá en tu negocio. Las citas ya agendadas no se borran.',
      confirmLabel: 'Eliminar',
      color: AppColors.red,
    );
    if (!ok) return;
    try {
      await Database.instance.deleteItem(widget.business.id, existing.id);
      if (!mounted) return;
      showMessage(context, 'Eliminado.');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showMessage(context, 'No se pudo eliminar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    final isService = _kind == ItemKind.servicio;

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew
            ? (isService ? 'Nuevo servicio' : 'Nuevo producto')
            : (isService ? 'Editar servicio' : 'Editar producto')),
        actions: [
          if (!isNew)
            IconButton(
              tooltip: 'Eliminar',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline, color: AppColors.red),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
          children: [
            const SectionLabel('¿Qué vas a agregar?'),
            SegmentedButton<ItemKind>(
              segments: const [
                ButtonSegment(
                  value: ItemKind.servicio,
                  icon: Icon(Icons.content_cut),
                  label: Text('Servicio'),
                ),
                ButtonSegment(
                  value: ItemKind.producto,
                  icon: Icon(Icons.shopping_bag_outlined),
                  label: Text('Producto'),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (v) => setState(() => _kind = v.first),
            ),
            const SizedBox(height: 6),
            Text(
              isService
                  ? 'Servicio: algo que se agenda, como un corte o un masaje. Lleva precio y duración.'
                  : 'Producto: algo que vendes en el negocio, como un shampoo. Lleva precio y piezas en inventario.',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SectionLabel('Imagen'),
            ImagePickerBox(
              value: _image,
              onChanged: (v) => setState(() => _image = v),
            ),
            const SectionLabel('Información'),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: fieldDecoration('Nombre'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Escribe el nombre' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _description,
              maxLines: 3,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              decoration: fieldDecoration('Descripción'),
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: fieldDecoration('Ej. 150', icon: Icons.attach_money)
                  .copyWith(labelText: 'Precio (MXN)'),
              validator: (v) {
                final p = double.tryParse((v ?? '').trim());
                if (p == null) return 'Escribe un precio válido';
                if (p <= 0) return 'El precio debe ser mayor a 0';
                return null;
              },
            ),
            const SizedBox(height: 10),
            if (isService)
              DropdownButtonFormField<int>(
                initialValue: _minutes,
                decoration: fieldDecoration('Duración', icon: Icons.schedule)
                    .copyWith(labelText: 'Duración del servicio'),
                items: [
                  for (var m = 15; m <= 240; m += 15)
                    DropdownMenuItem(value: m, child: Text(durationText(m))),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _minutes = v);
                },
              )
            else
              TextFormField(
                controller: _stock,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: fieldDecoration('Ej. 10', icon: Icons.inventory_2_outlined).copyWith(
                  labelText: 'Existencias (piezas en inventario)',
                  helperText: '¿Cuántas piezas de este producto tienes? Se descuentan con el botón − del inventario.',
                ),
                validator: (v) =>
                    int.tryParse((v ?? '').trim()) == null ? 'Escribe un número' : null,
              ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Visible para los clientes'),
              subtitle: const Text('Si lo apagas, se oculta sin borrarlo.'),
              value: _active,
              activeThumbColor: AppColors.teal,
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: isNew ? 'Guardar' : 'Guardar cambios',
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
