import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../config/map_config.dart';
import 'package:geolocator/geolocator.dart' show Position;
import 'package:latlong2/latlong.dart' show LatLng;

import '../logic/geo.dart';
import '../logic/schedule.dart';
import '../models/models.dart';
import '../services/geocoding.dart';
import '../services/location_service.dart';
import '../theme/app_colors.dart';
import 'common.dart';
import 'images.dart';

/// Sección "Negocios cerca de ti" del inicio del cliente.
///
/// Pide permiso de ubicación, muestra un mapa con el punto azul de la persona
/// y los negocios cercanos, y se actualiza solo cuando la persona se mueve.
/// La ubicación nunca se guarda: solo se usa en el teléfono.
class NearbySection extends StatefulWidget {
  const NearbySection({super.key, required this.businesses, required this.onOpen});

  final List<Business> businesses;
  final void Function(Business business) onOpen;

  @override
  State<NearbySection> createState() => _NearbySectionState();
}

class _NearbySectionState extends State<NearbySection> {
  static const List<double> _radii = [1000, 3000, 5000, 10000]; // 1, 3, 5 y 10 km
  double _radius = 5000; // 5 km
  bool _onlyOpen = false;

  LocationAccess? _access; // null = todavía no pide permiso
  bool _starting = false;
  LatLng? _me;
  StreamSubscription<Position>? _sub;

  final _map = MapController();
  bool _mapReady = false;
  final _pages = PageController(viewportFraction: 0.86);
  String? _selectedId;

  // Ubicaciones encontradas por dirección (negocios que no marcaron su punto).
  final Map<String, LatLng?> _found = {};
  bool _geocoding = false;

  @override
  void initState() {
    super.initState();
    // Si ya dio permiso antes, arranca sin preguntar otra vez.
    LocationService.alreadyGranted().then((ok) {
      if (ok && mounted) _start();
    });
  }

  @override
  void didUpdateWidget(covariant NearbySection old) {
    super.didUpdateWidget(old);
    if (_me != null) _geocodeMissing();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pages.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _starting = true);
    final access = await LocationService.requestAccess();
    if (!mounted) return;
    setState(() => _access = access);
    if (access != LocationAccess.granted) {
      setState(() => _starting = false);
      return;
    }
    final first = await LocationService.current();
    if (!mounted) return;
    if (first != null) _update(first);
    setState(() => _starting = false);
    _sub?.cancel();
    _sub = LocationService.positions().listen(_update, onError: (_) {});
    _geocodeMissing();
  }

  void _update(Position p) {
    final me = LatLng(p.latitude, p.longitude);
    setState(() => _me = me);
    _fit();
  }

  /// Busca, una por una, las direcciones de negocios sin punto en el mapa.
  Future<void> _geocodeMissing() async {
    if (_geocoding) return;
    _geocoding = true;
    try {
      for (final b in widget.businesses) {
        if (!mounted) return;
        if (b.hasLocation || _found.containsKey(b.id) || b.address.trim().isEmpty) continue;
        final p = await Geocoding.search('${b.address}, Querétaro');
        if (!mounted) return;
        setState(() => _found[b.id] = p);
        // El servicio gratuito pide máximo una búsqueda por segundo.
        await Future<void>.delayed(const Duration(milliseconds: 1100));
      }
    } finally {
      _geocoding = false;
    }
  }

  LatLng? _pointOf(Business b) =>
      b.hasLocation ? LatLng(b.latitude!, b.longitude!) : _found[b.id];

  List<NearbyEntry<Business>> get _nearby {
    final me = _me;
    if (me == null) return const [];
    final now = DateTime.now();
    ({double lat, double lng})? locate(Business b) {
      final p = _pointOf(b);
      return p == null ? null : (lat: p.latitude, lng: p.longitude);
    }

    final inside = filterNearby<Business>(
      items: widget.businesses,
      locate: locate,
      userLat: me.latitude,
      userLng: me.longitude,
      radiusMeters: _radius,
      onlyOpen: _onlyOpen,
      isOpen: (b) => openingStatus(b, now).open,
    );
    // Si no hay nadie dentro del radio (y no se pidió "solo abiertos"), se
    // muestran los 3 más cercanos para que el mapa no quede sin puntos.
    if (inside.isNotEmpty || _onlyOpen) return inside;
    return nearestFirst<Business>(
      items: widget.businesses,
      locate: locate,
      userLat: me.latitude,
      userLng: me.longitude,
      radiusMeters: 0,
      fallback: 3,
    );
  }

  /// Verdadero cuando los negocios mostrados están fuera del radio elegido.
  bool get _outsideRadius {
    final n = _nearby;
    return n.isNotEmpty && n.first.meters > _radius;
  }

  void _setFilters({double? radius, bool? onlyOpen}) {
    setState(() {
      _radius = radius ?? _radius;
      _onlyOpen = onlyOpen ?? _onlyOpen;
      _selectedId = null;
    });
    if (_pages.hasClients) _pages.jumpToPage(0);
    _fit();
  }

  /// Chips de radio e interruptor "Solo abiertos ahora".
  Widget _filters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final r in _radii)
              ChoiceChip(
                label: Text(radiusLabel(r)),
                selected: r == _radius,
                selectedColor: AppColors.sky,
                onSelected: (_) => _setFilters(radius: r),
              ),
          ],
        ),
        Row(
          children: [
            const Expanded(
              child: Text('Solo abiertos ahora', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            Switch(
              value: _onlyOpen,
              activeThumbColor: AppColors.blue,
              onChanged: (v) => _setFilters(onlyOpen: v),
            ),
          ],
        ),
      ],
    );
  }

  /// Encuadra el mapa para que se vean la persona y los negocios más cercanos.
  void _fit() {
    final me = _me;
    if (me == null || !_mapReady) return;
    final points = [me, for (final e in _nearby.take(5)) _pointOf(e.item)!];
    if (points.length == 1) {
      _map.move(me, 15);
    } else {
      _map.fitCamera(CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.fromLTRB(40, 60, 40, 40),
        maxZoom: 16,
      ));
    }
  }

  void _select(Business b, {bool fromMap = false}) {
    setState(() => _selectedId = b.id);
    final i = _nearby.indexWhere((e) => e.item.id == b.id);
    if (fromMap && i >= 0 && _pages.hasClients) {
      _pages.animateToPage(i, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    }
    final p = _pointOf(b);
    if (!fromMap && p != null && _mapReady) _map.move(p, _map.camera.zoom < 15 ? 15 : _map.camera.zoom);
  }

  // ---------------------------------------------------------------- Vista
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.near_me_rounded, color: AppColors.teal, size: 20),
            const SizedBox(width: 6),
            const Text('Cerca de ti', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (_me != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.greenSoft, borderRadius: BorderRadius.circular(10)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 7, color: AppColors.green),
                    SizedBox(width: 4),
                    Text('En vivo', style: TextStyle(fontSize: 11, color: AppColors.green, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (_me == null) _invite() else ...[
          _filters(),
          const SizedBox(height: 4),
          _mapCard(),
          const SizedBox(height: 12),
          _carousel(),
        ],
      ],
    );
  }

  /// Antes de tener la ubicación: tarjeta para activarla.
  Widget _invite() {
    final access = _access;
    final String text;
    final String button;
    VoidCallback? action = _start;
    switch (access) {
      case LocationAccess.deniedForever:
        text = 'Bloqueaste la ubicación para Bookly. Actívala en los ajustes para ver negocios cerca de ti.';
        button = 'Abrir ajustes';
        action = LocationService.openSettings;
      case LocationAccess.serviceOff:
        text = 'Tu ubicación (GPS) está apagada. Enciéndela y vuelve a intentarlo.';
        button = 'Intentar de nuevo';
      case LocationAccess.denied:
        text = 'Sin permiso no podemos mostrarte qué hay cerca. Puedes intentarlo otra vez cuando quieras.';
        button = 'Permitir ubicación';
      case LocationAccess.granted:
        text = 'Buscando dónde estás…';
        button = 'Buscando…';
        action = null;
      case null:
        text = 'Activa tu ubicación y te mostramos en el mapa las barberías, estéticas y spas '
            'más cerca de ti. Se actualiza mientras te mueves.';
        button = 'Activar ubicación';
    }
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [AppColors.teal, AppColors.blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _RadarPainter())),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Descubre lo que hay en tu zona',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                SizedBox(
                  width: 250,
                  child: Text(text, style: const TextStyle(color: AppColors.mist, fontSize: 12, height: 1.35)),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _starting ? null : action,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.teal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _starting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location_rounded, size: 18),
                  label: Text(_starting ? 'Buscando…' : button),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapCard() {
    final me = _me!;
    final nearby = _nearby;
    return Container(
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x22143F48), blurRadius: 18, offset: Offset(0, 8))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: me,
              initialZoom: 14,
              minZoom: 4,
              maxZoom: 19,
              backgroundColor: AppColors.mist,
              interactionOptions: const InteractionOptions(
                // Sin arrastrar con un dedo, para que la página se pueda desplazar.
                flags: InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom | InteractiveFlag.pinchMove,
              ),
              onMapReady: () {
                _mapReady = true;
                _fit();
              },
            ),
            children: [
              booklyTileLayer(),
              CircleLayer(circles: [
                CircleMarker(
                  point: me,
                  radius: _radius,
                  useRadiusInMeter: true,
                  color: AppColors.aqua.withValues(alpha: 0.08),
                  borderColor: AppColors.aqua.withValues(alpha: 0.5),
                  borderStrokeWidth: 1.5,
                ),
              ]),
              MarkerLayer(markers: [
                for (final e in nearby)
                  Marker(
                    point: _pointOf(e.item)!,
                    width: 46,
                    height: 56,
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () => _select(e.item, fromMap: true),
                      child: _MiniPin(business: e.item, selected: e.item.id == _selectedId),
                    ),
                  ),
                Marker(point: me, width: 60, height: 60, child: const _MeDot()),
              ]),
              booklyAttribution(),
            ],
          ),
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 8)],
              ),
              child: Text(
                nearby.isEmpty
                    ? 'Sin negocios'
                    : _outsideRadius
                        ? 'Ninguno en ${radiusLabel(_radius)} · los más cercanos'
                        : '${nearby.length} ${nearby.length == 1 ? 'negocio' : 'negocios'} cerca',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.teal),
              ),
            ),
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 3,
              child: IconButton(
                tooltip: 'Centrar en mí',
                onPressed: _fit,
                icon: const Icon(Icons.my_location_rounded, color: AppColors.blue),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _carousel() {
    final nearby = _nearby;
    if (nearby.isEmpty) {
      final km = radiusLabel(_radius);
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          _onlyOpen ? 'No hay negocios abiertos en $km' : 'No hay negocios en $km',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted),
        ),
      );
    }
    final now = DateTime.now();
    return SizedBox(
      height: 112,
      child: PageView.builder(
        controller: _pages,
        padEnds: false,
        itemCount: nearby.length,
        onPageChanged: (i) => _select(nearby[i].item),
        itemBuilder: (context, i) {
          final e = nearby[i];
          final b = e.item;
          final status = openingStatus(b, now);
          final selected = b.id == _selectedId;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => widget.onOpen(b),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: selected ? b.accent : AppColors.line, width: selected ? 2 : 1),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          width: 88,
                          height: 88,
                          child: b.coverBase64 != null
                              ? Base64Image(data: b.coverBase64, radius: 0)
                              : b.logoBase64 != null
                                  ? Base64Image(data: b.logoBase64, radius: 0)
                                  : GradientBox(
                                      colors: b.colors,
                                      radius: 0,
                                      child: Icon(b.category.icon, color: Colors.white, size: 34),
                                    ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(b.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(b.categoryLabel,
                                style: TextStyle(color: b.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.directions_walk_rounded, size: 15, color: AppColors.muted),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    '${distanceText(e.meters)} · ${walkingMinutes(e.meters)} min',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              status.open ? 'Abierto ahora' : 'Cerrado',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: status.open ? AppColors.green : AppColors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (b.rating > 0)
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.star_rounded, color: AppColors.amber, size: 20),
                            Text(b.rating.toStringAsFixed(1),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Punto azul de la persona, con un halo que late.
class _MeDot extends StatefulWidget {
  const _MeDot();

  @override
  State<_MeDot> createState() => _MeDotState();
}

class _MeDotState extends State<_MeDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 18 + 40 * t,
              height: 18 + 40 * t,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.blue.withValues(alpha: 0.30 * (1 - t)),
              ),
            ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.blue,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 6)],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Marcador pequeño de un negocio en el mapa de "Cerca de ti".
class _MiniPin extends StatelessWidget {
  const _MiniPin({required this.business, required this.selected});

  final Business business;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final b = business;
    final size = selected ? 42.0 : 34.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size,
          height: size,
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            color: b.accent,
            shape: BoxShape.circle,
            boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 3))],
          ),
          child: ClipOval(
            child: b.logoBase64 != null
                ? Base64Image(data: b.logoBase64, radius: 0)
                : Container(
                    color: Colors.white,
                    alignment: Alignment.center,
                    child: Icon(b.category.icon, color: b.accent, size: size * 0.5),
                  ),
          ),
        ),
        CustomPaint(size: const Size(10, 7), painter: _TipPainter(b.accent)),
      ],
    );
  }
}

class _TipPainter extends CustomPainter {
  _TipPainter(this.color);
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
  bool shouldRepaint(covariant _TipPainter old) => old.color != color;
}

/// Círculos tipo radar para la tarjeta de "Activar ubicación".
class _RadarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.86, size.height * 0.42);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0x33FFFFFF);
    for (final r in [28.0, 58.0, 92.0, 130.0]) {
      canvas.drawCircle(center, r, ring);
    }
    canvas.drawCircle(center, 9, Paint()..color = Colors.white);
    canvas.drawCircle(center, 5, Paint()..color = AppColors.blue);
    final dot = Paint()..color = const Color(0xCCFFFFFF);
    canvas.drawCircle(center + const Offset(-46, -30), 5, dot);
    canvas.drawCircle(center + const Offset(30, 52), 5, dot);
    canvas.drawCircle(center + const Offset(-70, 46), 4, dot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
