import 'package:flutter/material.dart';

import '../logic/schedule.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import 'common.dart';
import 'images.dart';

/// Servicios o productos de un negocio.
///
///  - Si el negocio les puso clasificación (Cortes, Barba...), arriba van las
///    clasificaciones para filtrar y cada una se muestra como un carrusel.
///  - Si no clasificó nada, se muestran en cuadrícula de dos columnas.
/// Cada tarjeta: nombre y precio → imagen completa → botón Reservar / Comprar.
class CatalogView extends StatefulWidget {
  const CatalogView({
    super.key,
    required this.items,
    required this.business,
    this.onBook,
    this.onBuy,
  });

  final List<Item> items;
  final Business business;
  final void Function(Item item)? onBook; // servicios
  final void Function(Item item)? onBuy; // productos (null = no se vende en línea)

  @override
  State<CatalogView> createState() => _CatalogViewState();
}

class _CatalogViewState extends State<CatalogView> {
  String? _selected; // null = todas las clasificaciones

  @override
  Widget build(BuildContext context) {
    final classified = widget.items.any((i) => i.section.trim().isNotEmpty);
    if (!classified) return _grid();

    final groups = groupBySection(widget.items);
    final names = [for (final g in groups) g.name];
    if (_selected != null && !names.contains(_selected)) _selected = null;
    final visible = _selected == null ? groups : groups.where((g) => g.name == _selected).toList();
    final accent = widget.business.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (groups.length > 1) ...[
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _chip('Todo', null, widget.items.length, accent),
                for (final g in groups) _chip(g.name, g.name, g.items.length, accent),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        for (final g in visible) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 2),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 8),
                  Text(g.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 6),
                  Text('${g.items.length}', style: const TextStyle(color: AppColors.muted)),
                  const Spacer(),
                  if (g.items.length > 1)
                    const Row(
                      children: [
                        Text('Desliza', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                        Icon(Icons.swipe_left_rounded, size: 16, color: AppColors.muted),
                      ],
                    ),
                ],
              ),
            ),
          _ItemCarousel(
            key: ValueKey('carousel-${g.name}'),
            items: g.items,
            business: widget.business,
            onBook: widget.onBook,
            onBuy: widget.onBuy,
          ),
          const SizedBox(height: 18),
        ],
      ],
    );
  }

  /// Sin clasificaciones: cuadrícula de dos columnas.
  Widget _grid() {
    return LayoutBuilder(builder: (context, c) {
      const gap = 12.0;
      // Tarjetas de máximo ~230 px: en pantallas anchas caben más columnas.
      final columns = ((c.maxWidth + gap) / (230 + gap)).floor().clamp(2, 6);
      final cardWidth = (c.maxWidth - gap * (columns - 1)) / columns;
      final imageHeight = cardWidth - 20; // imagen cuadrada
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final item in widget.items)
            SizedBox(
              width: cardWidth,
              height: imageHeight + 140,
              child: _ItemCard(
                item: item,
                business: widget.business,
                imageHeight: imageHeight,
                compact: true,
                onBook: widget.onBook,
                onBuy: widget.onBuy,
              ),
            ),
        ],
      );
    });
  }

  Widget _chip(String label, String? value, int count, Color accent) {
    final selected = _selected == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selected = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? AppColors.ink : AppColors.gray),
          ),
          child: Text(
            '$label · $count',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemCarousel extends StatefulWidget {
  const _ItemCarousel({
    super.key,
    required this.items,
    required this.business,
    this.onBook,
    this.onBuy,
  });

  final List<Item> items;
  final Business business;
  final void Function(Item item)? onBook;
  final void Function(Item item)? onBuy;

  @override
  State<_ItemCarousel> createState() => _ItemCarouselState();
}

class _ItemCarouselState extends State<_ItemCarousel> {
  PageController? _pages;
  double _fraction = 0;

  /// Cada tarjeta mide como máximo ~340 px, para que en pantallas anchas
  /// se vean varias a la vez y la imagen no se estire.
  PageController _controllerFor(double width) {
    final f = (340 / width).clamp(0.2, widget.items.length > 1 ? 0.86 : 1.0);
    if (_pages == null || (f - _fraction).abs() > 0.01) {
      final old = _pages;
      _pages = PageController(viewportFraction: f, initialPage: old?.hasClients == true ? _page : 0);
      _fraction = f;
      WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
    }
    return _pages!;
  }
  int _page = 0;

  @override
  void dispose() {
    _pages?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    return LayoutBuilder(builder: (context, c) {
      final controller = _controllerFor(c.maxWidth);
      final cardWidth = c.maxWidth * _fraction - (items.length > 1 ? 12 : 0);
      final imageHeight = ((cardWidth - 24) * 0.72).clamp(150.0, 320.0);
      final height = 214 + imageHeight;
      return Column(
        children: [
          SizedBox(
            height: height,
            child: PageView.builder(
              controller: controller,
              padEnds: false,
              itemCount: items.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => Padding(
                padding: EdgeInsets.only(right: items.length > 1 ? 12 : 0, bottom: 6),
                child: _ItemCard(
                  item: items[i],
                  business: widget.business,
                  imageHeight: imageHeight,
                  onBook: widget.onBook,
                  onBuy: widget.onBuy,
                ),
              ),
            ),
          ),
          if (items.length > 1) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < items.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _page ? widget.business.accent : AppColors.sky,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ],
        ],
      );
    });
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.business,
    required this.imageHeight,
    this.compact = false,
    this.onBook,
    this.onBuy,
  });

  final Item item;
  final Business business;
  final double imageHeight;
  final bool compact; // tarjeta chica para la cuadrícula
  final void Function(Item item)? onBook;
  final void Function(Item item)? onBuy;

  @override
  Widget build(BuildContext context) {
    final i = item;
    final accent = business.accent;
    final soldOut = !i.isService && i.stock <= 0;

    final Widget button;
    if (i.isService) {
      button = FilledButton.icon(
        onPressed: onBook == null ? null : () => onBook!(i),
        style: _buttonStyle(AppColors.blue),
        icon: const Icon(Icons.event_available_rounded, size: 20),
        label: const Text('Reservar'),
      );
    } else if (soldOut) {
      button = FilledButton(onPressed: null, style: _buttonStyle(AppColors.blue), child: const Text('Agotado'));
    } else if (onBuy != null) {
      button = FilledButton.icon(
        onPressed: () => onBuy!(i),
        style: _buttonStyle(AppColors.teal),
        icon: const Icon(Icons.shopping_bag_rounded, size: 20),
        label: const Text('Comprar'),
      );
    } else {
      button = OutlinedButton.icon(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.storefront_outlined, size: 18),
        label: Text(compact ? 'En el negocio' : 'Disponible en el negocio'),
      );
    }

    if (compact) return _compactCard(button, accent, soldOut);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
        boxShadow: const [BoxShadow(color: Color(0x14143F48), blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Nombre y precio arriba
          SizedBox(
            height: 44,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                i.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, height: 1.2),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 22,
            child: Row(
              children: [
                Text(money(i.price),
                    style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 17)),
                const SizedBox(width: 8),
                if (i.isService)
                  _pill(Icons.schedule_rounded, durationText(i.minutes))
                else
                  _pill(Icons.inventory_2_outlined, soldOut ? 'Sin piezas' : '${i.stock} disponibles'),
                const Spacer(),
                if (i.isService)
                  Flexible(
                    child: Text('Anticipo ${money2(i.deposit)}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // 2. Imagen completa (sin recortar)
          SizedBox(height: imageHeight, child: _image(56)),
          const SizedBox(height: 10),
          SizedBox(
            height: 34,
            child: Text(
              i.description.isEmpty ? ' ' : i.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.35),
            ),
          ),
          const Spacer(),
          // 3. Botón abajo de la imagen
          button,
        ],
      ),
    );
  }

  Widget _image(double iconSize) => item.imageBase64 != null
      ? FramedImage(data: item.imageBase64!)
      : GradientBox(
          colors: business.colors,
          radius: 16,
          child: Center(
            child: Icon(
              item.isService ? Icons.content_cut_rounded : Icons.shopping_bag_outlined,
              size: iconSize,
              color: const Color(0x88FFFFFF),
            ),
          ),
        );

  /// Tarjeta chica (cuadrícula): nombre y precio, imagen, botón.
  Widget _compactCard(Widget button, Color accent, bool soldOut) {
    final i = item;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
        boxShadow: const [BoxShadow(color: Color(0x10143F48), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 38,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(i.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, height: 1.2)),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            i.isService
                ? '${money(i.price)} · ${durationText(i.minutes)}'
                : '${money(i.price)} · ${soldOut ? 'Agotado' : '${i.stock} pzas'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const SizedBox(height: 8),
          SizedBox(height: imageHeight, child: _image(40)),
          const Spacer(),
          SizedBox(height: 42, child: button),
        ],
      ),
    );
  }

  ButtonStyle _buttonStyle(Color color) => FilledButton.styleFrom(
        backgroundColor: color,
        minimumSize: const Size.fromHeight(46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      );

  Widget _pill(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: AppColors.mist, borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.teal),
            const SizedBox(width: 3),
            Text(text, style: const TextStyle(fontSize: 11, color: AppColors.teal, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
