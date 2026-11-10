import 'package:flutter/material.dart';

import '../logic/schedule.dart';
import '../models/models.dart';
import '../services/database.dart';
import '../theme/app_colors.dart';
import '../widgets/business_info_view.dart';
import '../widgets/catalog_view.dart';
import '../widgets/common.dart';
import '../widgets/images.dart';
import '../widgets/post_card.dart';
import '../widgets/site_widgets.dart';
import 'booking_screen.dart';
import 'order_screen.dart';

/// Abre el sitio de un negocio.
void openBusiness(BuildContext context, Business business) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => BusinessScreen(business: business)),
  );
}

/// Sitio del negocio tal como lo ven los clientes: portada, logo y eslogan,
/// y pestañas de servicios, productos, fotos, novedades e información
/// (mapa, dirección, horario, personal y contacto).
///
/// Con [preview] = true el dueño ve su propio sitio sin poder reservar.
class BusinessScreen extends StatefulWidget {
  const BusinessScreen({super.key, required this.business, this.preview = false});

  final Business business;
  final bool preview;

  @override
  State<BusinessScreen> createState() => _BusinessScreenState();
}

class _BusinessScreenState extends State<BusinessScreen> {
  int _tab = 0; // 0 Servicios, 1 Productos, 2 Fotos, 3 Novedades, 4 Información
  late final Stream<Business?> _business = Database.instance.businessStream(widget.business.id);
  late final Stream<List<Item>> _items = Database.instance.itemsStream(widget.business.id);
  late final Stream<List<GalleryPhoto>> _gallery =
      Database.instance.galleryStream(widget.business.id);
  late final Stream<List<Post>> _posts = Database.instance.postsByBusiness(widget.business.id);

  void _book(Business b, Item service) {
    if (widget.preview) {
      showMessage(context, 'Vista previa: así verán tus clientes el botón Reservar.');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BookingScreen(business: b, service: service)),
    );
  }

  void _buy(Business b, Item product) {
    if (widget.preview) {
      showMessage(context, 'Vista previa: así verán tus clientes el botón Comprar.');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OrderScreen(business: b, product: product)),
    );
  }

  static const _tabInfo = [
    (Icons.content_cut_rounded, 'Servicios'),
    (Icons.shopping_bag_outlined, 'Productos'),
    (Icons.photo_library_outlined, 'Fotos'),
    (Icons.play_circle_outline_rounded, 'Novedades'),
    (Icons.info_outline_rounded, 'Información'),
  ];

  /// Pestañas como "pastillas" que se deslizan de lado.
  Widget _tabs(Color accent) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _tabInfo.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (icon, label) = _tabInfo[i];
          final selected = _tab == i;
          return GestureDetector(
            onTap: () => setState(() => _tab = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected ? accent : Colors.white,
                borderRadius: BorderRadius.circular(21),
                border: Border.all(color: selected ? accent : AppColors.gray),
                boxShadow: selected
                    ? [BoxShadow(color: accent.withValues(alpha: 0.30), blurRadius: 10, offset: const Offset(0, 4))]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: selected ? Colors.white : accent),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color: selected ? Colors.white : AppColors.ink,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Fila corta bajo el nombre: calificación y si está abierto.
  /// Al tocarla se abre la pestaña Información.
  Widget _quickInfo(Business b) {
    final status = openingStatus(b, DateTime.now());
    final color = status.open ? AppColors.green : AppColors.red;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (b.rating > 0)
          StatusBadge('★ ${b.rating.toStringAsFixed(1)}',
              color: const Color(0xFFB57511), background: AppColors.amberSoft),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _tab = 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: status.open ? AppColors.greenSoft : AppColors.redSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 8, color: color),
                const SizedBox(width: 6),
                Text(status.text,
                    style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded, size: 16, color: color),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _itemsTab(Business b, {required bool services}) {
    return StreamBuilder<List<Item>>(
      stream: _items,
      builder: (context, snapshot) {
        final status = streamStatus(snapshot);
        if (status != null) return status;
        final list = snapshot.data!
            .where((i) => i.active && i.isService == services)
            .toList();
        if (list.isEmpty) {
          return EmptyMessage(
            icon: services ? Icons.content_cut : Icons.shopping_bag_outlined,
            text: services
                ? 'Este negocio aún no publica servicios.'
                : 'Este negocio aún no publica productos.',
          );
        }
        return CatalogView(
          items: list,
          business: b,
          onBook: services ? (item) => _book(b, item) : null,
          // Los negocios de ejemplo no venden en línea.
          onBuy: !services && !b.demo ? (item) => _buy(b, item) : null,
        );
      },
    );
  }

  Widget _galleryTab() {
    return StreamBuilder<List<GalleryPhoto>>(
      stream: _gallery,
      builder: (context, snapshot) {
        final status = streamStatus(snapshot);
        if (status != null) return status;
        final photos = snapshot.data!;
        if (photos.isEmpty) {
          return const EmptyMessage(
            icon: Icons.photo_library_outlined,
            text: 'Este negocio aún no sube fotos.',
          );
        }
        return GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: [
            for (final p in photos)
              GestureDetector(
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => Dialog(
                    clipBehavior: Clip.antiAlias,
                    child: Base64Image(data: p.imageBase64, radius: 0, fit: BoxFit.contain),
                  ),
                ),
                child: Base64Image(data: p.imageBase64, radius: 10),
              ),
          ],
        );
      },
    );
  }

  Widget _postsTab() {
    return StreamBuilder<List<Post>>(
      stream: _posts,
      builder: (context, snapshot) {
        final status = streamStatus(snapshot);
        if (status != null) return status;
        final posts = snapshot.data!;
        if (posts.isEmpty) {
          return const EmptyMessage(
            icon: Icons.campaign_outlined,
            text: 'Sin publicaciones por ahora.',
          );
        }
        return Column(
          children: [
            for (final p in posts)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PostCard(post: p),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    // Se escucha el negocio para que los cambios de diseño se vean al momento.
    return StreamBuilder<Business?>(
      stream: _business,
      initialData: widget.business,
      builder: (context, snapshot) {
        final b = snapshot.data ?? widget.business;
        final Widget content = switch (_tab) {
          1 => _itemsTab(b, services: false),
          2 => _galleryTab(),
          3 => _postsTab(),
          4 => BusinessInfoView(business: b),
          _ => _itemsTab(b, services: true),
        };

        return Scaffold(
          appBar: widget.preview
              ? AppBar(
                  title: const Text('Vista previa de tu sitio'),
                  backgroundColor: AppColors.amberSoft,
                )
              : null,
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              BusinessSiteHeader(
                business: b,
                topInset: widget.preview ? 0 : top,
                leading: widget.preview
                    ? null
                    : IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(backgroundColor: const Color(0x33000000)),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _quickInfo(b),
                    const SizedBox(height: 16),
                    _tabs(b.accent),
                    const SizedBox(height: 14),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      // Todo alineado a la izquierda (no al centro).
                      layoutBuilder: (current, previous) => Stack(
                        alignment: Alignment.topLeft,
                        children: [...previous, ?current],
                      ),
                      child: KeyedSubtree(key: ValueKey(_tab), child: content),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
