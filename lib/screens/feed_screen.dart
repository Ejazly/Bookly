import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/database.dart';
import '../theme/app_colors.dart';
import '../ads/ads.dart';
import '../widgets/common.dart';
import '../widgets/post_card.dart';
import 'business_screen.dart';

/// Novedades: publicaciones de los últimos 8 días, agrupadas por negocio.
/// Cada negocio tiene su fila y sus publicaciones se deslizan de lado
/// (carrusel). Las de más de 8 días ya no salen aquí, pero siguen en el
/// sitio del negocio.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final Stream<List<Post>> _stream = Database.instance.recentFeedStream();

  Future<void> _openBusiness(String businessId) async {
    try {
      final b = await Database.instance.getBusiness(businessId);
      if (!mounted) return;
      if (b == null) {
        showMessage(context, 'Este negocio ya no está disponible.');
        return;
      }
      openBusiness(context, b);
    } catch (e) {
      if (mounted) showMessage(context, 'No se pudo abrir: $e');
    }
  }

  /// Agrupa por negocio; primero el que publicó más recientemente.
  List<List<Post>> _groups(List<Post> posts) {
    final order = <String>[];
    final map = <String, List<Post>>{};
    for (final p in posts) {
      if (!map.containsKey(p.businessId)) {
        order.add(p.businessId);
        map[p.businessId] = [];
      }
      map[p.businessId]!.add(p);
    }
    return [for (final id in order) map[id]!];
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<Post>>(
        stream: _stream,
        builder: (context, snapshot) {
          final status = streamStatus(snapshot);
          final groups = status == null ? _groups(snapshot.data!) : const <List<Post>>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 0, 18),
            children: [
              const Padding(
                padding: EdgeInsets.only(right: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Novedades',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.ink)),
                    Text('Lo nuevo de cada negocio en los últimos ${Database.feedDays} días',
                        style: TextStyle(color: AppColors.muted)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (status != null)
                status
              else if (groups.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(right: 18),
                  child: EmptyMessage(
                    icon: Icons.dynamic_feed_outlined,
                    text: 'Esta semana todavía no hay publicaciones.',
                  ),
                )
              else
                for (var i = 0; i < groups.length; i++) ...[
                  _BusinessRow(posts: groups[i], onOpen: () => _openBusiness(groups[i].first.businessId)),
                  const SizedBox(height: 22),
                  // Un anuncio cada dos negocios.
                  if (i.isOdd) ...[
                    AdBanner(key: ValueKey('ad-$i'), large: true),
                    const SizedBox(height: 22),
                  ],
                ],
            ],
          );
        },
      ),
    );
  }
}

/// Fila de un negocio: encabezado y sus publicaciones en carrusel.
class _BusinessRow extends StatelessWidget {
  const _BusinessRow({required this.posts, required this.onOpen});

  final List<Post> posts;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final first = posts.first;
    final screen = MediaQuery.sizeOf(context).width;
    // En el celular se asoma la siguiente publicación; en la compu caben varias.
    final cardWidth = (screen * 0.82).clamp(240.0, 340.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 12, bottom: 10),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [first.category.colors.first, AppColors.aqua]),
                ),
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(first.category.icon, size: 20, color: first.category.colors.first),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(first.businessName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                      '${posts.length} ${posts.length == 1 ? 'publicación' : 'publicaciones'} · ${first.category.label}',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onOpen,
                style: TextButton.styleFrom(foregroundColor: AppColors.blue),
                child: const Text('Ver negocio'),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(right: 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final p in posts)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: cardWidth,
                    child: PostCard(post: p, showBusiness: false),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
