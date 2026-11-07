import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/database.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/images.dart';
import '../widgets/post_card.dart';
import '../widgets/site_widgets.dart';
import 'booking_screen.dart';

/// Abre el sitio de un negocio.
void openBusiness(BuildContext context, Business business) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => BusinessScreen(business: business)),
  );
}

/// Sitio del negocio tal como lo ven los clientes: portada, logo, eslogan,
/// "acerca de", contacto, servicios, productos, fotos y publicaciones.
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
  int _tab = 0; // 0 Servicios, 1 Productos, 2 Fotos, 3 Publicaciones
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

  Widget _tabs(Color accent) {
    const labels = ['Servicios', 'Productos', 'Fotos', 'Novedades'];
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFDDE3E5))),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _tab = i),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: _tab == i ? accent : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 13,
                      color: _tab == i ? accent : AppColors.muted,
                      fontWeight: _tab == i ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
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
        return Column(
          children: [
            for (final item in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ItemCard(
                  item: item,
                  accent: b.accent,
                  onBook: services ? () => _book(b, item) : null,
                ),
              ),
          ],
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
        final closed = b.closedWeekdays.toList()..sort();
        final Widget content = switch (_tab) {
          1 => _itemsTab(b, services: false),
          2 => _galleryTab(),
          3 => _postsTab(),
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (b.rating > 0)
                          StatusBadge('★ ${b.rating.toStringAsFixed(1)}',
                              color: const Color(0xFFB57511), background: AppColors.amberSoft),
                        StatusBadge('Horario ${b.hoursText}'),
                        if (closed.isNotEmpty)
                          StatusBadge(
                            'Cierra ${closed.map(weekdayShort).join(', ')}',
                            color: AppColors.muted,
                            background: AppColors.light,
                          ),
                      ],
                    ),
                    if (b.description.isNotEmpty) ...[
                      const SectionLabel('Acerca de nosotros'),
                      Text(b.description, style: const TextStyle(height: 1.4)),
                    ],
                    const SectionLabel('Nuestro equipo'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final m in b.team)
                          StatusBadge(
                            '${m.name} · ${m.hoursText}',
                            color: b.accent,
                            background: AppColors.light,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SocialLinks(business: b),
                    const SizedBox(height: 14),
                    _tabs(b.accent),
                    const SizedBox(height: 12),
                    content,
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

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.accent, this.onBook});

  final Item item;
  final Color accent;
  final VoidCallback? onBook; // null = producto (no se agenda)

  @override
  Widget build(BuildContext context) {
    final i = item;
    return AppCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Base64Image(
            data: i.imageBase64,
            width: 72,
            height: 72,
            placeholderIcon: i.isService ? Icons.content_cut : Icons.shopping_bag_outlined,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(i.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                if (i.description.isNotEmpty)
                  Text(i.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(money(i.price),
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        )),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        i.isService
                            ? durationText(i.minutes)
                            : (i.stock > 0 ? 'Disponible en el negocio' : 'Agotado'),
                        style: TextStyle(
                          fontSize: 12,
                          color: !i.isService && i.stock <= 0
                              ? AppColors.red
                              : AppColors.muted,
                        ),
                      ),
                    ),
                    if (onBook != null)
                      FilledButton(
                        onPressed: onBook,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.green,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Reservar'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
