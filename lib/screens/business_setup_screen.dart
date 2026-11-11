import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../models/models.dart';
import '../services/database.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/location_map.dart';

/// Datos del negocio: se usa para darlo de alta y para editarlo.
class BusinessSetupScreen extends StatefulWidget {
  const BusinessSetupScreen({super.key, this.existing});

  /// null = negocio nuevo.
  final Business? existing;

  @override
  State<BusinessSetupScreen> createState() => _BusinessSetupScreenState();
}

class _BusinessSetupScreenState extends State<BusinessSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _customCategory = TextEditingController();
  final List<_StaffDraft> _team = [];
  BusinessCategory _category = BusinessCategory.barberias;
  // Horario de cada día (1 = lunes ... 7 = domingo).
  final Map<int, _DayDraft> _days = {
    for (var d = DateTime.monday; d <= DateTime.sunday; d++)
      d: _DayDraft(open: d != DateTime.sunday, start: 10, end: 20),
  };
  /// Hora de apertura más temprana y de cierre más tarde de los días que abre
  /// (se guardan como horario general para compatibilidad).
  int get _open {
    final open = _days.values.where((d) => d.open).map((d) => d.start);
    return open.isEmpty ? 10 : open.reduce((a, b) => a < b ? a : b);
  }

  int get _close {
    final open = _days.values.where((d) => d.open).map((d) => d.end);
    return open.isEmpty ? 20 : open.reduce((a, b) => a > b ? a : b);
  }

  bool _saving = false;
  bool _filled = false;
  LatLng? _location; // dónde está el negocio en el mapa

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_filled) return;
    _filled = true;
    final b = widget.existing;
    if (b != null) {
      _name.text = b.name;
      _address.text = b.address;
      _phone.text = b.phone;
      _customCategory.text = b.customCategory;
      for (final m in b.team) {
        _team.add(_StaffDraft(m.name, m.startHour, m.endHour, m.daysOff));
      }
      _category = b.category;
      if (b.hasLocation) _location = LatLng(b.latitude!, b.longitude!);
      for (var d = DateTime.monday; d <= DateTime.sunday; d++) {
        final h = b.hoursForWeekday(d);
        _days[d] = _DayDraft(
          open: h != null,
          start: h?.open ?? b.openHour,
          end: h?.close ?? b.closeHour,
        );
      }
    } else {
      _team.add(_StaffDraft(AppScope.read(context).firstName, _open, _close, const {}));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    _customCategory.dispose();
    for (final d in _team) {
      d.name.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_days.values.any((d) => d.open)) {
      showMessage(context, 'Marca al menos un día en que abre tu negocio.');
      return;
    }
    for (final e in _days.entries) {
      if (e.value.open && e.value.end <= e.value.start) {
        showMessage(context,
            'El ${weekdayLong(e.key)} la hora de cierre debe ser después de la de apertura.');
        return;
      }
    }
    final session = AppScope.read(context);
    final user = session.user;
    if (user == null) return;

    // Personal: cada persona con su turno y sus días de descanso.
    final team = <StaffMember>[];
    for (final d in _team) {
      final name = d.name.text.trim();
      if (name.isEmpty) continue;
      if (d.end <= d.start) {
        showMessage(context, 'El turno de $name debe terminar después de que empieza.');
        return;
      }
      team.add(StaffMember(
        name: name,
        startHour: d.start,
        endHour: d.end,
        daysOff: Set<int>.of(d.off),
      ));
    }
    if (team.isEmpty) {
      showMessage(context, 'Agrega al menos una persona que atienda.');
      return;
    }
    final names = team.map((m) => m.name).toSet();
    if (names.length != team.length) {
      showMessage(context, 'Hay dos personas con el mismo nombre. Usa nombres distintos.');
      return;
    }

    final business = Business(
      id: user.uid,
      ownerUid: user.uid,
      ownerEmail: session.email,
      name: _name.text.trim(),
      category: _category,
      address: _address.text.trim(),
      phone: _phone.text.trim(),
      openHour: _open,
      closeHour: _close,
      closedWeekdays: {
        for (final e in _days.entries)
          if (!e.value.open) e.key,
      },
      weeklyHours: {
        for (final e in _days.entries)
          e.key: e.value.open ? DayHours(e.value.start, e.value.end) : null,
      },
      professionals: [for (final m in team) m.name],
      staffMembers: team,
      customCategory: _category == BusinessCategory.otro ? _customCategory.text.trim() : '',
      rating: widget.existing?.rating ?? 0,
      latitude: _location?.latitude,
      longitude: _location?.longitude,
    );

    setState(() => _saving = true);
    try {
      // Al crear el negocio, el panel se abre en "Mi sitio" para decorarlo.
      if (widget.existing == null) session.businessTab = 1;
      await Database.instance.saveBusinessBasics(business);
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        showMessage(context, 'Datos del negocio guardados.');
        Navigator.of(context).pop();
      }
      // Si es la primera vez, AuthGate abre el panel del negocio solo.
    } catch (e) {
      if (mounted) showMessage(context, 'No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Una fila por día: interruptor abierto/cerrado, horas y copiar a todos.
  Widget _dayRow(int d) {
    final day = _days[d]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Switch(
                  value: day.open,
                  activeThumbColor: AppColors.teal,
                  onChanged: (v) => setState(() => day.open = v),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    weekdayLong(d)[0].toUpperCase() + weekdayLong(d).substring(1),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (!day.open)
                  const Text('Cerrado', style: TextStyle(color: AppColors.red)),
                IconButton(
                  tooltip: 'Copiar a todos los días',
                  icon: const Icon(Icons.copy_all_outlined, color: AppColors.teal),
                  onPressed: () => setState(() {
                    for (final other in _days.values) {
                      other.open = day.open;
                      other.start = day.start;
                      other.end = day.end;
                    }
                  }),
                ),
              ],
            ),
            if (day.open)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    _hourDropdown('Abre', day.start, (v) => setState(() => day.start = v)),
                    const SizedBox(width: 12),
                    _hourDropdown('Cierra', day.end, (v) => setState(() => day.end = v)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _hourDropdown(String label, int value, ValueChanged<int> onChanged) {
    return Expanded(
      child: DropdownButtonFormField<int>(
        initialValue: value,
        decoration: fieldDecoration(label),
        items: [
          for (var h = 5; h <= 23; h++)
            DropdownMenuItem(value: h, child: Text('$h:00')),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  /// Negocio de muestra para dibujar el marcador con su color y su logo.
  Business _previewBusiness() {
    final e = widget.existing;
    return Business(
      id: e?.id ?? '',
      ownerUid: '',
      ownerEmail: '',
      name: _name.text.trim(),
      category: _category,
      address: _address.text.trim(),
      phone: '',
      openHour: _open,
      closeHour: _close,
      closedWeekdays: const {},
      professionals: const [],
      themeIndex: e?.themeIndex ?? 0,
      logoBase64: e?.logoBase64,
    );
  }

  Future<void> _pickLocation() async {
    final point = await Navigator.of(context).push<LatLng>(MaterialPageRoute(
      builder: (_) => MapPickerScreen(
        address: _address.text,
        initial: _location,
        preview: _previewBusiness(),
      ),
    ));
    if (point != null) setState(() => _location = point);
  }

  Widget _locationCard() {
    final point = _location;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gray),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (point != null)
            SizedBox(
              height: 150,
              child: IgnorePointer(
                // El mapa pequeño solo se ve; para moverlo se abre el selector.
                child: BooklyMap(
                  key: ValueKey(point),
                  center: point,
                  zoom: 16,
                  marker: BusinessPin(business: _previewBusiness()),
                ),
              ),
            ),
          ListTile(
            leading: Icon(
              point == null ? Icons.add_location_alt_outlined : Icons.edit_location_alt_outlined,
              color: AppColors.teal,
            ),
            title: Text(point == null ? 'Marca tu negocio en el mapa' : 'Ubicación marcada'),
            subtitle: Text(point == null
                ? 'Así tus clientes verán dónde estás y cómo llegar.'
                : 'Toca para cambiarla.'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _pickLocation,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context);
    final isNew = widget.existing == null;
    final canGoBack = Navigator.of(context).canPop();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: canGoBack,
        title: Text(isNew ? 'Registra tu negocio' : 'Datos del negocio'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            if (isNew)
              const Text(
                'Paso 1 de 2: datos generales. Después podrás decorar tu sitio con portada, logo, colores y fotos.',
                style: TextStyle(color: AppColors.muted),
              ),
            const SectionLabel('Información general'),
            TextFormField(
              controller: _name,
              decoration: fieldDecoration('Nombre del negocio'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Escribe el nombre del negocio' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<BusinessCategory>(
              initialValue: _category,
              decoration: fieldDecoration('Categoría'),
              items: [
                for (final c in BusinessCategory.values)
                  DropdownMenuItem(
                    value: c,
                    child: Row(
                      children: [
                        Icon(c.icon, size: 18, color: AppColors.teal),
                        const SizedBox(width: 8),
                        Text(c.label),
                      ],
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _category = v);
              },
            ),
            if (_category == BusinessCategory.otro) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _customCategory,
                textCapitalization: TextCapitalization.sentences,
                decoration: fieldDecoration('¿Qué tipo de negocio es? (ej. Tatuajes, Pestañas, Masajes)',
                    icon: Icons.edit_outlined),
                validator: (v) => _category == BusinessCategory.otro && (v ?? '').trim().isEmpty
                    ? 'Escribe qué tipo de negocio es'
                    : null,
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              decoration: fieldDecoration('Dirección', icon: Icons.place_outlined),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Escribe la dirección' : null,
            ),
            const SizedBox(height: 10),
            _locationCard(),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: fieldDecoration('Teléfono (10 dígitos)', icon: Icons.phone_outlined),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return null; // opcional
                return RegExp(r'^\d{10}$').hasMatch(t)
                    ? null
                    : 'El teléfono debe tener 10 dígitos';
              },
            ),
            const SectionLabel('Horario'),
            const Text(
              'Cada día puede tener su propio horario. Apaga los días que no abres.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 6),
            for (var d = DateTime.monday; d <= DateTime.sunday; d++) _dayRow(d),
            const SectionLabel('Personal que atiende'),
            Text(
              'Cada persona tiene su propio turno y días de descanso. Al agendar, '
              'los clientes ven los horarios de cada quien y saben quién los atenderá. '
              'Los turnos se ajustan al horario del negocio ($_open:00 – $_close:00).',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < _team.length; i++)
              Padding(
                key: ObjectKey(_team[i]),
                padding: const EdgeInsets.only(bottom: 10),
                child: _StaffCard(
                  draft: _team[i],
                  canDelete: _team.length > 1,
                  hourDropdown: _hourDropdown,
                  onChanged: () => setState(() {}),
                  onDelete: () {
                    final removed = _team[i];
                    setState(() => _team.removeAt(i));
                    // Se libera el campo de texto cuando ya no está en pantalla.
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => removed.name.dispose());
                  },
                ),
              ),
            OutlinedButton.icon(
              onPressed: () => setState(() {
                _team.add(_StaffDraft('', _open, _close, const {}));
              }),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Agregar persona del personal'),
            ),
            const SectionLabel('Avisos por correo'),
            AppCard(
              color: AppColors.mist,
              child: Row(
                children: [
                  const Icon(Icons.mark_email_unread_outlined, color: AppColors.teal),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Cuando un cliente agende te avisaremos a ${session.email}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: isNew ? 'Crear mi negocio' : 'Guardar cambios',
              loading: _saving,
              onPressed: _save,
            ),
            if (isNew && !canGoBack) ...[
              const SizedBox(height: 8),
              if (session.profile?.isClient ?? false)
                TextButton(
                  onPressed: () => session.switchMode(AppMode.client),
                  child: const Text('Hacerlo después y entrar como cliente'),
                ),
              TextButton(
                onPressed: () => session.signOut(),
                child: const Text('Cerrar sesión'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Horario que se está editando de un día.
class _DayDraft {
  _DayDraft({required this.open, required this.start, required this.end});

  bool open;
  int start;
  int end;
}

/// Datos que se están editando de una persona del personal.
class _StaffDraft {
  _StaffDraft(String name, this.start, this.end, Set<int> off)
      : name = TextEditingController(text: name),
        off = Set<int>.of(off);

  final TextEditingController name;
  int start;
  int end;
  final Set<int> off;
}

/// Tarjeta para editar el nombre, el turno y los días de descanso de una persona.
class _StaffCard extends StatelessWidget {
  const _StaffCard({
    required this.draft,
    required this.canDelete,
    required this.hourDropdown,
    required this.onChanged,
    required this.onDelete,
  });

  final _StaffDraft draft;
  final bool canDelete;
  final Widget Function(String label, int value, ValueChanged<int> onChanged) hourDropdown;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final d = draft;
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: d.name,
                  textCapitalization: TextCapitalization.words,
                  decoration: fieldDecoration('Nombre', icon: Icons.person_outline),
                ),
              ),
              if (canDelete)
                IconButton(
                  tooltip: 'Quitar',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, color: AppColors.red),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              hourDropdown('Entra', d.start, (v) {
                d.start = v;
                onChanged();
              }),
              const SizedBox(width: 10),
              hourDropdown('Sale', d.end, (v) {
                d.end = v;
                onChanged();
              }),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Descansa', style: TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (var day = DateTime.monday; day <= DateTime.sunday; day++)
                FilterChip(
                  label: Text(weekdayShort(day)),
                  selected: d.off.contains(day),
                  visualDensity: VisualDensity.compact,
                  selectedColor: const Color(0x33C24D4D),
                  onSelected: (on) {
                    if (on) {
                      d.off.add(day);
                    } else {
                      d.off.remove(day);
                    }
                    onChanged();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
