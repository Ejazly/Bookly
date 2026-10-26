import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'booking_screen.dart';

/// Abre el perfil de un negocio.
void openBusiness(BuildContext context, Business business) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => BusinessScreen(business: business)),
  );
}

/// Pantalla 3.4: Perfil del negocio.
class BusinessScreen extends StatefulWidget {
  const BusinessScreen({super.key, required this.business});

  final Business business;

  @override
  State<BusinessScreen> createState() => _BusinessScreenState();
}

class _BusinessScreenState extends State<BusinessScreen> {
  int _tab = 0; // 0 Servicios, 1 Fotos, 2 Videos, 3 Reseñas
  bool _favorite = false;

  void _book(Service service) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            BookingScreen(business: widget.business, service: service),
      ),
    );
  }

  Widget _tabs() {
    const labels = ['Servicios', 'Fotos', 'Videos', 'Reseñas'];
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
                        color: _tab == i ? AppColors.teal : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: _tab == i ? AppColors.teal : AppColors.muted,
                      fontWeight:
                          _tab == i ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _services() {
    final b = widget.business;
    return [
      for (final s in b.services)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(durationText(s.minutes),
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 12)),
                    ],
                  ),
                ),
                Text(
                  money(s.price),
                  style: const TextStyle(
                    color: AppColors.teal,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: () => _book(s),
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
          ),
        ),
      if (b.promo != null)
        AppCard(
          color: AppColors.greenSoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PROMOCIÓN ACTIVA',
                style: TextStyle(
                  color: AppColors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 3),
              Text(b.promo!),
            ],
          ),
        ),
    ];
  }

  List<Widget> _photos() {
    final b = widget.business;
    return [
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: List.generate(
          6,
          (i) => GradientBox(
            colors: i.isEven ? b.colors : b.colors.reversed.toList(),
            child: const Icon(Icons.photo_outlined, color: Color(0x99FFFFFF)),
          ),
        ),
      ),
    ];
  }

  List<Widget> _videos() {
    final b = widget.business;
    return [
      for (var i = 0; i < 2; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () => showSoon(context),
            child: GradientBox(
              colors: i == 0 ? b.colors : b.colors.reversed.toList(),
              height: 170,
              radius: 16,
              child: Stack(
                children: [
                  const Center(
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: Color(0xE6FFFFFF),
                      child: Icon(Icons.play_arrow,
                          color: AppColors.teal, size: 32),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 10,
                    child: Text(
                      i == 0 ? b.videoCaption : 'Recorrido por nuestras instalaciones',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    ];
  }

  List<Widget> _reviews() {
    final b = widget.business;
    if (b.reviews.isEmpty) {
      return [const Text('Aún no hay reseñas.')];
    }
    return [
      for (final r in b.reviews)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(r.author,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    for (var i = 0; i < 5; i++)
                      Icon(
                        i < r.stars ? Icons.star : Icons.star_border,
                        color: AppColors.amber,
                        size: 16,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(r.text),
              ],
            ),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.business;
    final top = MediaQuery.of(context).padding.top;

    final List<Widget> content;
    switch (_tab) {
      case 1:
        content = _photos();
        break;
      case 2:
        content = _videos();
        break;
      case 3:
        content = _reviews();
        break;
      default:
        content = _services();
    }

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Portada
          Stack(
            children: [
              GradientBox(
                colors: b.colors,
                height: 200,
                radius: 0,
                child: Center(
                  child: Icon(b.category.icon,
                      size: 70, color: const Color(0x55FFFFFF)),
                ),
              ),
              Positioned(
                top: top + 6,
                left: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(
                      backgroundColor: const Color(0x33000000)),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
            ],
          ),
          // Tarjeta con la información (se sube sobre la portada)
          Transform.translate(
            offset: const Offset(0, -36),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            b.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              setState(() => _favorite = !_favorite),
                          icon: Icon(
                            _favorite ? Icons.favorite : Icons.favorite_border,
                            color: AppColors.red,
                          ),
                        ),
                      ],
                    ),
                    Text('${b.address} · ${b.distanceKm} km',
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Icon(Icons.star, color: AppColors.amber, size: 18),
                        Text('${b.rating}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('(${b.reviewCount} reseñas)',
                            style: const TextStyle(color: AppColors.muted)),
                        StatusBadge(
                            'Horario ${b.openHour}:00 – ${b.closeHour}:00'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _tabs(),
                  const SizedBox(height: 12),
                  ...content,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
