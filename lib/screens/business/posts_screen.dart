import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/database.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../widgets/post_card.dart';
import 'post_form_screen.dart';

/// Publicaciones del negocio. Aparecen en la sección Novedades de los clientes.
class PostsScreen extends StatefulWidget {
  const PostsScreen({super.key, required this.business});

  final Business business;

  @override
  State<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> {
  late final Stream<List<Post>> _stream =
      Database.instance.postsByBusiness(widget.business.id);

  void _new() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PostFormScreen(business: widget.business)),
    );
  }

  Future<void> _delete(Post p) async {
    final ok = await confirmDialog(
      context,
      title: '¿Eliminar publicación?',
      message: 'Dejará de aparecer en Novedades.',
      confirmLabel: 'Eliminar',
      color: AppColors.red,
    );
    if (!ok) return;
    try {
      await Database.instance.deletePost(p.id);
    } catch (e) {
      if (mounted) showMessage(context, 'No se pudo eliminar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Publicaciones')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _new,
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Nueva publicación'),
      ),
      body: StreamBuilder<List<Post>>(
        stream: _stream,
        builder: (context, snapshot) {
          final status = streamStatus(snapshot);
          if (status != null) return status;
          final posts = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 90),
            children: [
              const Text(
                'Comparte promociones, trabajos recientes o novedades. '
                'Tus clientes las ven en la sección Novedades.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              if (posts.isEmpty)
                EmptyMessage(
                  icon: Icons.campaign_outlined,
                  text: 'Todavía no has publicado nada.',
                  action: PrimaryButton(label: 'Crear mi primera publicación', onPressed: _new),
                )
              else
                for (final p in posts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PostCard(post: p, onDelete: () => _delete(p)),
                  ),
            ],
          );
        },
      ),
    );
  }
}
