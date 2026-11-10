import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../models/models.dart';
import '../services/geocoding.dart';
import '../theme/app_colors.dart';
import 'common.dart';
import 'images.dart';

/// Mapa de Bookly. Usa los mapas libres de OpenStreetMap con el estilo
/// "Voyager" de CARTO, que no necesitan llave ni cuenta de pago.
class BooklyMap extends StatelessWidget {
  const BooklyMap({
    super.key,
    required this.center,
    this.zoom = 16,
    this.interactive = false,
    this.marker,
    this.onTap,
    this.controller,
  });

  final LatLng center;
  final double zoom;

  /// false = solo se puede acercar con dos dedos o doble toque (para que la
  /// página se pueda desplazar sin mover el mapa).
  final bool interactive;
  final Widget? marker;
  final void Function(LatLng point)? onTap;
  final MapController? controller;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        minZoom: 4,
        maxZoom: 19,
        backgroundColor: AppColors.mist,
        interactionOptions: InteractionOptions(
          flags: interactive
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
        ),
        onTap: onTap == null ? null : (_, point) => onTap!(point),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          retinaMode: RetinaMode.isHighDensity(context),
          maxNativeZoom: 20,
          userAgentPackageName: 'mx.uaq.bookly',
        ),
        if (marker != null)
          MarkerLayer(
            markers: [
              Marker(
                point: center,
                width: 120,
                height: 120,
                child: marker!,
              ),
            ],
          ),
        const RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          showFlutterMapAttribution: false,
          attributions: [
            TextSourceAttribution('OpenStreetMap'),
            TextSourceAttribution('CARTO'),
          ],
        ),
      ],
    );
  }
}

/// Marcador del negocio: una gota con su logo (o la inicial) en su color,
/// con un halo que "late" para que se note dónde está.
class BusinessPin extends StatefulWidget {
  const BusinessPin({super.key, required this.business});

  final Business business;

  @override
  State<BusinessPin> createState() => _BusinessPinState();
}

class _BusinessPinState extends State<BusinessPin> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.business;
    final color = b.accent;
    // El marcador mide 120 x 120 y su punta queda justo en el centro.
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Halo justo en el punto (el centro del marcador)
          AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                final t = _pulse.value;
                return Container(
                  width: 16 + 36 * t,
                  height: (16 + 36 * t) * 0.45,
                  decoration: BoxDecoration(
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.all(Radius.elliptical(26 + 36 * t, 12 + 16 * t)),
                    color: color.withValues(alpha: 0.35 * (1 - t)),
                  ),
                );
              },
            ),
          // Gota
          Positioned(
            bottom: 60,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(color: Color(0x55000000), blurRadius: 10, offset: Offset(0, 4)),
                    ],
                  ),
                  child: ClipOval(
                    child: b.logoBase64 != null
                        ? Base64Image(data: b.logoBase64, radius: 0)
                        : Container(
                            color: Colors.white,
                            alignment: Alignment.center,
                            child: Icon(b.category.icon, color: color, size: 24),
                          ),
                  ),
                ),
                CustomPaint(size: const Size(16, 10), painter: _PinTipPainter(color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PinTipPainter extends CustomPainter {
  _PinTipPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PinTipPainter old) => old.color != color;
}

/// Pantalla para que el negocio marque dónde está: busca la dirección o
/// toca el mapa para mover la marca. Regresa el punto elegido.
class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key, required this.address, this.initial, required this.preview});

  final String address;
  final LatLng? initial;
  final Business preview; // para dibujar el marcador con su color y logo

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final _map = MapController();
  late final _search = TextEditingController(text: widget.address);
  LatLng? _point;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _point = widget.initial;
    if (_point == null && widget.address.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _find());
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    FocusScope.of(context).unfocus();
    setState(() => _searching = true);
    final found = await Geocoding.search(_search.text);
    if (!mounted) return;
    setState(() => _searching = false);
    if (found == null) {
      showMessage(context, 'No encontramos esa dirección. Toca el mapa para marcar tu negocio.');
      return;
    }
    setState(() => _point = found);
    _map.move(found, 17);
  }

  @override
  Widget build(BuildContext context) {
    final point = _point;
    return Scaffold(
      appBar: AppBar(title: const Text('Ubica tu negocio')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: point ?? Geocoding.queretaro,
              initialZoom: point == null ? 13 : 17,
              minZoom: 4,
              maxZoom: 19,
              backgroundColor: AppColors.mist,
              interactionOptions:
                  const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              onTap: (_, p) => setState(() => _point = p),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                retinaMode: RetinaMode.isHighDensity(context),
                maxNativeZoom: 20,
                userAgentPackageName: 'mx.uaq.bookly',
              ),
              if (point != null)
                MarkerLayer(markers: [
                  Marker(
                    point: point,
                    width: 120,
                    height: 120,
                    child: BusinessPin(business: widget.preview),
                  ),
                ]),
              const RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                showFlutterMapAttribution: false,
                attributions: [
                  TextSourceAttribution('OpenStreetMap'),
                  TextSourceAttribution('CARTO'),
                ],
              ),
            ],
          ),
          // Buscador flotante
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Material(
              elevation: 6,
              shadowColor: const Color(0x33000000),
              borderRadius: BorderRadius.circular(16),
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _find(),
                decoration: InputDecoration(
                  hintText: 'Calle, número, colonia, ciudad',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.teal),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : IconButton(
                          tooltip: 'Buscar',
                          onPressed: _find,
                          icon: const Icon(Icons.arrow_forward_rounded, color: AppColors.blue),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
          ),
          // Indicación y botón para confirmar
          Positioned(
            left: 12,
            right: 12,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.deep.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.touch_app_outlined, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          point == null
                              ? 'Toca el mapa en el lugar exacto de tu negocio.'
                              : 'Si la marca no quedó justo en tu local, toca el lugar correcto.',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                PrimaryButton(
                  label: 'Usar esta ubicación',
                  onPressed: point == null ? null : () => Navigator.of(context).pop(point),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
