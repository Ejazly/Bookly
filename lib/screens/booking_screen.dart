import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'payment_screen.dart';

/// Pantalla 3.6: Agendar cita.
///
/// Se usa para reservar una cita nueva y también para reprogramar una
/// existente (cuando [rescheduling] no es null).
class BookingScreen extends StatefulWidget {
  const BookingScreen({
    super.key,
    required this.business,
    required this.service,
    this.rescheduling,
  });

  final Business business;
  final Service service;
  final Appointment? rescheduling;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  static const int _daysToShow = 14;

  final _note = TextEditingController();
  late List<DateTime> _days;
  late DateTime _day; // día seleccionado
  DateTime? _time; // horario seleccionado
  Professional? _pro; // null = "Cualquiera"
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final state = AppScope.of(context);
    final today = dateOnly(state.now);
    _days = List.generate(
      _daysToShow,
      (i) => DateTime(today.year, today.month, today.day + i),
    );

    final r = widget.rescheduling;
    if (r != null) {
      _day = dateOnly(r.start);
      _pro = r.professional;
    } else {
      // Primer día que tenga al menos un horario libre.
      _day = _days.firstWhere(
        (d) => state
            .slotsFor(widget.business, widget.service, d)
            .any((t) => state.isSlotAvailable(widget.business, widget.service, t)),
        orElse: () => _days.first,
      );
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool _available(AppState state, DateTime t) => state.isSlotAvailable(
        widget.business,
        widget.service,
        t,
        preferred: _pro,
        ignoreId: widget.rescheduling?.id,
      );

  void _selectDay(DateTime d) {
    setState(() {
      _day = d;
      _time = null;
    });
  }

  void _selectProfessional(Professional? p) {
    final state = AppScope.read(context);
    setState(() {
      _pro = p;
      // Si el horario elegido ya no está libre con este profesional, se quita.
      final t = _time;
      if (t != null && !_available(state, t)) _time = null;
    });
  }

  void _continue() {
    final t = _time;
    if (t == null) return;
    final state = AppScope.read(context);
    final r = widget.rescheduling;

    if (r != null) {
      try {
        state.reschedule(r, t, preferred: _pro);
        showMessage(context,
            'Cita reprogramada para el ${shortDate(t)} a las ${hhmm(t)}.');
        Navigator.of(context).pop();
      } on BookingException catch (e) {
        showMessage(context, e.message);
      }
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          business: widget.business,
          service: widget.service,
          start: t,
          preferred: _pro,
          note: _note.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final b = widget.business;
    final s = widget.service;
    final isReschedule = widget.rescheduling != null;
    final slots = state.slotsFor(b, s, _day);
    final selected = _time;

    return Scaffold(
      appBar: AppBar(
        title: Text(isReschedule ? 'Reprogramar cita' : 'Agendar cita'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        children: [
          // Resumen del servicio
          AppCard(
            child: Row(
              children: [
                GradientBox(
                  colors: b.colors,
                  width: 50,
                  height: 50,
                  child: Icon(b.category.icon, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('${b.name} · ${durationText(s.minutes)}',
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
              ],
            ),
          ),

          // Días
          SectionLabel(monthYear(_day)),
          SizedBox(
            height: 68,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _days.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final d = _days[i];
                return _DayChip(
                  date: d,
                  selected: sameDay(d, _day),
                  enabled: b.isOpenOn(d),
                  onTap: () => _selectDay(d),
                );
              },
            ),
          ),

          // Horarios
          const SectionLabel('Horarios disponibles'),
          if (!b.isOpenOn(_day))
            const Text('El negocio no abre este día. Elige otra fecha.',
                style: TextStyle(color: AppColors.muted))
          else if (slots.isEmpty)
            const Text('No hay horarios para este día.',
                style: TextStyle(color: AppColors.muted))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in slots)
                  _SlotChip(
                    label: hhmm(t),
                    selected: selected != null && selected == t,
                    enabled: _available(state, t),
                    onTap: () => setState(() => _time = t),
                  ),
              ],
            ),
          const SizedBox(height: 8),
          const Text(
            'Los horarios tachados ya están ocupados o ya pasaron.',
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),

          // Profesional
          const SectionLabel('Profesional (opcional)'),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: [
              _ProChip(
                name: 'Cualquiera',
                selected: _pro == null,
                onTap: () => _selectProfessional(null),
              ),
              for (final p in b.professionals)
                _ProChip(
                  name: p.name,
                  selected: _pro?.id == p.id,
                  onTap: () => _selectProfessional(p),
                ),
            ],
          ),

          // Nota
          if (!isReschedule) ...[
            const SectionLabel('Nota para el negocio'),
            TextField(
              controller: _note,
              maxLines: 2,
              decoration: fieldDecoration('Ej. degradado bajo'),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE1E6E8))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    selected == null
                        ? 'Elige un horario'
                        : '${shortDate(selected)} · ${hhmm(selected)}',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  if (!isReschedule)
                    Text.rich(
                      TextSpan(
                        text: 'Anticipo: ',
                        children: [
                          TextSpan(
                            text: money2(s.deposit),
                            style: const TextStyle(
                              color: AppColors.teal,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              PrimaryButton(
                label: isReschedule ? 'Confirmar nuevo horario' : 'Continuar al pago',
                onPressed: selected == null ? null : _continue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.date,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color background = selected
        ? AppColors.teal
        : (enabled ? Colors.white : const Color(0xFFE3E8EA));
    final Color textColor = selected
        ? Colors.white
        : (enabled ? AppColors.ink : const Color(0xFFA9B4B9));
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 50,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(dayName(date),
                style: TextStyle(fontSize: 11, color: textColor)),
            const SizedBox(height: 2),
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color background = selected
        ? AppColors.teal
        : (enabled ? Colors.white : const Color(0xFFF3F5F6));
    final Color textColor = selected
        ? Colors.white
        : (enabled ? AppColors.ink : const Color(0xFFB9C1C5));
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 74,
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.teal : AppColors.gray),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            decoration: enabled ? null : TextDecoration.lineThrough,
          ),
        ),
      ),
    );
  }
}

class _ProChip extends StatelessWidget {
  const _ProChip({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isAny = name == 'Cualquiera';
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.green : Colors.transparent,
                width: 3,
              ),
            ),
            child: CircleAvatar(
              radius: 22,
              backgroundColor:
                  selected ? AppColors.teal : const Color(0xFF8AA9B0),
              child: isAny
                  ? const Icon(Icons.groups_outlined, color: Colors.white)
                  : Text(
                      name[0],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(name, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
