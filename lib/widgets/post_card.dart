import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import 'common.dart';
import 'images.dart';
import 'video_post_player.dart';

/// Tarjeta de una publicación (se usa en Novedades y en el panel del negocio).
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    this.onDelete,
    this.onOpenBusiness,
    this.showBusiness = true,
  });

  final Post post;
  final VoidCallback? onDelete; // solo para el dueño
  final VoidCallback? onOpenBusiness; // solo para clientes

  /// false = no repite el nombre del negocio (ya está en el encabezado del grupo).
  final bool showBusiness;

  @override
  Widget build(BuildContext context) {
    final p = post;
    // Ancho de la publicación: la foto (máx. 480) + un margen de 12 por lado.
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 504),
        child: AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!showBusiness)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: Text(timeAgo(p.createdAt, DateTime.now()),
                  style: const TextStyle(color: AppColors.muted, fontSize: 11)),
            )
          else
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: p.category.colors.first,
                  child: Icon(p.category.icon, size: 18, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.businessName,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(timeAgo(p.createdAt, DateTime.now()),
                          style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                    ],
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    tooltip: 'Eliminar',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, color: AppColors.muted),
                  ),
              ],
            ),
          ),
          // La foto o el video conservan su forma; la tarjeta solo es un poco
          // más grande que ellos.
          if (p.hasVideo || p.imageBase64 != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: p.hasVideo
                    ? VideoPostPlayer(url: p.videoUrl!, colors: p.category.colors)
                    : AdaptiveImage(data: p.imageBase64!),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Text(p.text, style: const TextStyle(height: 1.35)),
          ),
          if (onOpenBusiness != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: OutlinedButton.icon(
                onPressed: onOpenBusiness,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.blue,
                  side: const BorderSide(color: AppColors.blue),
                ),
                icon: const Icon(Icons.storefront_outlined),
                label: const Text('Ver negocio y reservar'),
              ),
            ),
        ],
      ),
        ),
      ),
    );
  }
}
