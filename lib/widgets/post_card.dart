import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import 'common.dart';
import 'images.dart';

/// Tarjeta de una publicación (se usa en Novedades y en el panel del negocio).
class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post, this.onDelete, this.onOpenBusiness});

  final Post post;
  final VoidCallback? onDelete; // solo para el dueño
  final VoidCallback? onOpenBusiness; // solo para clientes

  @override
  Widget build(BuildContext context) {
    final p = post;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          if (p.imageBase64 != null)
            Base64Image(data: p.imageBase64, height: 230, radius: 0),
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
                  foregroundColor: AppColors.teal,
                  side: const BorderSide(color: AppColors.teal),
                ),
                icon: const Icon(Icons.storefront_outlined),
                label: const Text('Ver negocio y reservar'),
              ),
            ),
        ],
      ),
    );
  }
}
