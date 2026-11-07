import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/database.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import '../widgets/post_card.dart';
import 'business_screen.dart';

/// Novedades: publicaciones recientes de todos los negocios.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final Stream<List<Post>> _stream = Database.instance.feedStream();

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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<Post>>(
        stream: _stream,
        builder: (context, snapshot) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            children: [
              const Text(
                'Novedades',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
              const Text('Promociones y trabajos de los negocios',
                  style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 14),
              if (streamStatus(snapshot) case final status?)
                status
              else if (snapshot.data!.isEmpty)
                const EmptyMessage(
                  icon: Icons.dynamic_feed_outlined,
                  text: 'Aún no hay publicaciones.',
                )
              else
                for (final p in snapshot.data!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PostCard(
                      post: p,
                      onOpenBusiness: () => _openBusiness(p.businessId),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
