import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../logic/schedule.dart';
import '../models/models.dart';
import '../services/geocoding.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import '../utils/links.dart';
import 'common.dart';
import 'location_map.dart';

/// Pestaña "Información" del sitio de un negocio: mapa con su ubicación
/// (como en Google Maps), dirección, si está abierto, horario de la semana,
/// quién atiende y cómo contactarlo.
class BusinessInfoView extends StatefulWidget {
  const BusinessInfoView({super.key, required this.business});

  final Business business;

  @override
  State<BusinessInfoView> createState() => _BusinessInfoViewState();
}

class _BusinessInfoViewState extends State<BusinessInfoView> {
  Future<LatLng?>? _lookup;

  Business get b => widget.business;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant BusinessInfoView old) {
    super.didUpdateWidget(old);
    if (old.business.address != b.address ||
        old.business.latitude != b.latitude ||
        old.business.longitude != b.longitude) {
      _resolve();
    }
  }

  /// Si el negocio marcó su ubicación se usa esa; si no, se busca su dirección.
  void _resolve() {
    _lookup = b.hasLocation
        ? Future.value(LatLng(b.latitude!, b.longitude!))
        : Geocoding.search('${b.address}, Querétaro');
  }

  Future<void> _open(Uri uri) async {
    final ok = await openExternal(uri);
    if (!ok && mounted) showMessage(context, 'No se pudo abrir.');
  }

  void _copyAddress() {
    Clipboard.setData(ClipboardData(text: b.address));
    showMessage(context, 'Dirección copiada');
  }

  void _openFullMap(LatLng point) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _FullMapScreen(business: b, point: point),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final status = openingStatus(b, now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _mapCard(status),
        if (b.description.isNotEmpty) ...[
          const SizedBox(height: 18),
          _AboutCard(text: b.description, accent: b.accent),
        ],
        const SizedBox(height: 18),
        _sectionTitle(Icons.schedule_rounded, 'Horario'),
        _HoursCard(business: b, now: now),
        const SizedBox(height: 18),
        _sectionTitle(Icons.groups_2_outlined, 'Quién te atiende'),
        _TeamStrip(business: b, now: now),
        if (b.phone.isNotEmpty || b.whatsapp.isNotEmpty || b.instagram.isNotEmpty || b.facebook.isNotEmpty) ...[
          const SizedBox(height: 18),
          _sectionTitle(Icons.forum_outlined, 'Contacto'),
          _contactGrid(),
        ],
      ],
    );
  }

  Widget _sectionTitle(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 2),
        child: Row(
          children: [
            Icon(icon, size: 18, color: b.accent),
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      );

  // ------------------------------------------------------------------ Mapa
  Widget _mapCard(({bool open, String text}) status) {
    return Container(
      height: 340,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x22143F48), blurRadius: 18, offset: Offset(0, 8))],
      ),
      clipBehavior: Clip.antiAlias,
      child: FutureBuilder<LatLng?>(
        future: _lookup,
        builder: (context, snap) {
          final point = snap.data;
          final Widget background;
          if (snap.connectionState != ConnectionState.done) {
            background = Container(
              color: AppColors.mist,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            );
          } else if (point == null) {
            background = _NoMapBackground(colors: b.colors);
          } else {
            background = BooklyMap(center: point, marker: BusinessPin(business: b));
          }
          return Stack(
            children: [
              Positioned.fill(child: background),
              Positioned(top: 12, left: 12, child: _OpenChip(status: status)),
              if (point != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _GlassButton(
                    icon: Icons.open_in_full_rounded,
                    tooltip: 'Ver mapa completo',
                    onTap: () => _openFullMap(point),
                  ),
                ),
              Positioned(left: 12, right: 12, bottom: 12, child: _addressCard()),
            ],
          );
        },
      ),
    );
  }

  Widget _addressCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration:
                    BoxDecoration(color: AppColors.mist, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.place_rounded, color: b.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(b.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(b.address.isEmpty ? 'Dirección no registrada' : b.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Copiar dirección',
                onPressed: b.address.isEmpty ? null : _copyAddress,
                icon: const Icon(Icons.copy_rounded, size: 20, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilledButton.icon(
              onPressed: () => _open(directionsUri(b)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.blue,
                minimumSize: const Size.fromHeight(40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.directions_rounded, size: 18),
              label: const Text('Cómo llegar'),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- Contacto
  Widget _contactGrid() {
    final items = <Widget>[
      if (b.phone.isNotEmpty)
        _ContactTile(
          icon: Icons.call_rounded,
          label: 'Llamar',
          value: b.phone,
          color: AppColors.teal,
          onTap: () => _open(phoneUri(b.phone)),
        ),
      if (b.whatsapp.isNotEmpty)
        _ContactTile(
          icon: Icons.chat_rounded,
          label: 'WhatsApp',
          value: b.whatsapp,
          color: const Color(0xFF25A35A),
          onTap: () => _open(whatsappUri(b.whatsapp)),
        ),
      if (b.instagram.isNotEmpty)
        _ContactTile(
          icon: Icons.camera_alt_rounded,
          label: 'Instagram',
          value: '@${b.instagram.replaceAll('@', '')}',
          color: const Color(0xFFC13584),
          onTap: () => _open(instagramUri(b.instagram)),
        ),
      if (b.facebook.isNotEmpty)
        _ContactTile(
          icon: Icons.facebook_rounded,
          label: 'Facebook',
          value: b.facebook,
          color: const Color(0xFF1877F2),
          onTap: () => _open(facebookUri(b.facebook)),
        ),
    ];
    return LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - 10) / 2;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [for (final i in items) SizedBox(width: w, child: i)],
      );
    });
  }
}

// ============================================================== Piezas

class _OpenChip extends StatelessWidget {
  const _OpenChip({required this.status});

  final ({bool open, String text}) status;

  @override
  Widget build(BuildContext context) {
    final color = status.open ? AppColors.green : AppColors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 8)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(status.text,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, size: 20, color: AppColors.teal),
      ),
    );
  }
}

/// Si no se encontró la ubicación: fondo con "calles" dibujadas.
class _NoMapBackground extends StatelessWidget {
  const _NoMapBackground({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.mist, AppColors.sky.withValues(alpha: 0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: CustomPaint(
        painter: _StreetsPainter(),
        child: Align(
          alignment: const Alignment(0, -0.25),
          child: Icon(Icons.location_on_rounded, size: 56, color: colors.first),
        ),
      ),
    );
  }
}

class _StreetsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    final small = Paint()
      ..color = const Color(0xAAFFFFFF)
      ..strokeWidth = 4;
    canvas.drawLine(Offset(0, size.height * 0.35), Offset(size.width, size.height * 0.2), road);
    canvas.drawLine(Offset(size.width * 0.3, 0), Offset(size.width * 0.45, size.height), road);
    canvas.drawLine(Offset(size.width * 0.75, 0), Offset(size.width * 0.65, size.height), small);
    canvas.drawLine(Offset(0, size.height * 0.7), Offset(size.width, size.height * 0.62), small);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.mist,
        borderRadius: BorderRadius.circular(20),
        border: Border(left: BorderSide(color: accent, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.format_quote_rounded, color: accent, size: 28),
          const SizedBox(height: 2),
          Text(text, style: const TextStyle(height: 1.45, color: AppColors.ink)),
        ],
      ),
    );
  }
}

class _HoursCard extends StatelessWidget {
  const _HoursCard({required this.business, required this.now});

  final Business business;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final b = business;
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: Column(
        children: [
          for (var d = 1; d <= 7; d++)
            Builder(builder: (context) {
              final today = now.weekday == d;
              final closed = b.closedWeekdays.contains(d);
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 2),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: today ? b.accent.withValues(alpha: 0.10) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 92,
                      child: Text(
                        weekdayLong(d)[0].toUpperCase() + weekdayLong(d).substring(1),
                        style: TextStyle(
                          fontWeight: today ? FontWeight.bold : FontWeight.normal,
                          color: today ? b.accent : AppColors.ink,
                        ),
                      ),
                    ),
                    if (today)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: b.accent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('Hoy',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    const Spacer(),
                    Text(
                      closed ? 'Cerrado' : b.hoursText,
                      style: TextStyle(
                        color: closed ? AppColors.red : AppColors.ink,
                        fontWeight: today ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _TeamStrip extends StatelessWidget {
  const _TeamStrip({required this.business, required this.now});

  final Business business;
  final DateTime now;

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final second = parts.length > 1 ? parts[1][0] : '';
    return (first + second).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final b = business;
    final team = b.team;
    return SizedBox(
      height: 172,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: team.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final m = team[i];
          final onShift = memberOnShift(b, m, now);
          final off = m.daysOff.toList()..sort();
          return Container(
            width: 148,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: i.isEven
                              ? const [AppColors.teal, AppColors.aqua]
                              : const [AppColors.blue, AppColors.aqua],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Text(_initials(m.name),
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                    ),
                    if (onShift)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: AppColors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(m.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(m.hoursText, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: onShift ? AppColors.greenSoft : AppColors.mist,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    onShift
                        ? 'En turno ahora'
                        : off.isEmpty
                            ? 'Todos los días'
                            : 'Descansa ${off.map(weekdayShort).join(', ')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: onShift ? AppColors.green : AppColors.teal,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mapa en pantalla completa (se puede mover y acercar).
class _FullMapScreen extends StatelessWidget {
  const _FullMapScreen({required this.business, required this.point});

  final Business business;
  final LatLng point;

  @override
  Widget build(BuildContext context) {
    final b = business;
    return Scaffold(
      appBar: AppBar(title: Text(b.name)),
      body: Stack(
        children: [
          Positioned.fill(
            child: BooklyMap(
              center: point,
              zoom: 17,
              interactive: true,
              marker: BusinessPin(business: b),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: PrimaryButton(
              label: 'Abrir en Google Maps',
              onPressed: () => openExternal(directionsUri(b)),
            ),
          ),
        ],
      ),
    );
  }
}
