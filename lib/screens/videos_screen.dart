import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import 'business_screen.dart';

/// Pantalla 3.5: Videos promocionales (feed vertical tipo reels).
/// Por ahora cada "video" es un fondo con degradado; el reproductor real
/// se agregará con el paquete video_player y Firebase Storage.
class VideosScreen extends StatelessWidget {
  const VideosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Container(
      color: const Color(0xFF0B2E36),
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 10, 18, 10),
              child: Row(
                children: [
                  Text(
                    'Para ti',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(width: 18),
                  Text(
                    'Siguiendo',
                    style: TextStyle(color: Color(0x99FFFFFF), fontSize: 16),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                scrollDirection: Axis.vertical,
                itemCount: state.businesses.length,
                itemBuilder: (context, i) =>
                    _VideoPage(business: state.businesses[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPage extends StatelessWidget {
  const _VideoPage({required this.business});

  final Business business;

  @override
  Widget build(BuildContext context) {
    final b = business;
    return Stack(
      fit: StackFit.expand,
      children: [
        GradientBox(
          colors: [b.colors.first, AppColors.deep, const Color(0xFF081F25)],
          radius: 0,
        ),
        Center(
          child: GestureDetector(
            onTap: () => showSoon(context),
            child: const CircleAvatar(
              radius: 32,
              backgroundColor: Color(0xE6FFFFFF),
              child: Icon(Icons.play_arrow, color: AppColors.teal, size: 38),
            ),
          ),
        ),
        // Acciones a la derecha
        Positioned(
          right: 12,
          bottom: 130,
          child: Column(
            children: [
              _action(Icons.favorite, '${b.reviewCount * 7}'),
              const SizedBox(height: 18),
              _action(Icons.chat_bubble_outline, '${b.reviewCount ~/ 3}'),
              const SizedBox(height: 18),
              _action(Icons.share_outlined, 'Compartir'),
            ],
          ),
        ),
        // Información del negocio y botón
        Positioned(
          left: 16,
          right: 80,
          bottom: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: b.colors.first,
                    child: Icon(b.category.icon, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      b.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                b.videoCaption,
                style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 13),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  onPressed: () => openBusiness(context, b),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.green,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Ver negocio y reservar'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _action(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
      ],
    );
  }
}
