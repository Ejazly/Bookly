import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_colors.dart';
import 'common.dart';
import 'images.dart';

/// Encabezado del sitio de un negocio: portada, logo, nombre y eslogan.
/// Se usa en la página que ven los clientes y en la vista previa de "Mi sitio".
class BusinessSiteHeader extends StatelessWidget {
  const BusinessSiteHeader({
    super.key,
    required this.business,
    this.coverHeight = 190,
    this.topInset = 0,
    this.leading,
  });

  final Business business;
  final double coverHeight;
  final double topInset; // espacio de la barra de estado
  final Widget? leading; // ej. botón de regresar

  @override
  Widget build(BuildContext context) {
    final b = business;
    const logoSize = 84.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: coverHeight + topInset,
              child: b.coverBase64 != null
                  ? Base64Image(data: b.coverBase64, radius: 0)
                  : GradientBox(
                      colors: b.colors,
                      radius: 0,
                      child: Center(
                        child: Icon(b.category.icon, size: 64, color: const Color(0x55FFFFFF)),
                      ),
                    ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(18, logoSize / 2 + 8, 18, 14),
              child: Column(
                children: [
                  Text(
                    b.name.isEmpty ? 'Nombre de tu negocio' : b.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  if (b.slogan.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      b.slogan,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: b.accent, fontStyle: FontStyle.italic),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    '${b.categoryLabel} · ${b.address}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        // Logo redondo encimado entre la portada y el nombre
        Positioned(
          top: coverHeight + topInset - logoSize / 2,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: logoSize,
              height: logoSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8)],
              ),
              child: ClipOval(
                child: b.logoBase64 != null
                    ? Base64Image(data: b.logoBase64, radius: 0)
                    : Container(
                        color: b.accent,
                        alignment: Alignment.center,
                        child: Text(
                          b.name.isEmpty ? '?' : b.name[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
        if (leading != null) Positioned(top: topInset + 6, left: 8, child: leading!),
      ],
    );
  }
}

/// Logo pequeño (o inicial) para listas.
class BusinessLogo extends StatelessWidget {
  const BusinessLogo({super.key, required this.business, this.size = 64});

  final Business business;
  final double size;

  @override
  Widget build(BuildContext context) {
    final b = business;
    if (b.logoBase64 != null) {
      return Base64Image(data: b.logoBase64, width: size, height: size);
    }
    return GradientBox(
      colors: b.colors,
      width: size,
      height: size,
      child: Icon(b.category.icon, color: Colors.white, size: size * 0.44),
    );
  }
}

/// Fila de botones de contacto y redes sociales.
class SocialLinks extends StatelessWidget {
  const SocialLinks({super.key, required this.business});

  final Business business;

  @override
  Widget build(BuildContext context) {
    final b = business;
    final chips = <Widget>[
      if (b.phone.isNotEmpty) _chip(Icons.phone_outlined, b.phone),
      if (b.whatsapp.isNotEmpty) _chip(Icons.chat_outlined, 'WhatsApp ${b.whatsapp}'),
      if (b.instagram.isNotEmpty) _chip(Icons.camera_alt_outlined, '@${b.instagram}'),
      if (b.facebook.isNotEmpty) _chip(Icons.facebook, b.facebook),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _chip(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.gray),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: business.accent),
            const SizedBox(width: 6),
            Text(text, style: const TextStyle(fontSize: 12)),
          ],
        ),
      );
}
