import 'package:flutter/material.dart';

import '../logic/schedule.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';

/// Fila horizontal de días (Lun 26, Mar 27, ...).
class DaySelector extends StatelessWidget {
  const DaySelector({
    super.key,
    required this.days,
    required this.selected,
    required this.onSelected,
    this.isEnabled,
  });

  final List<DateTime> days;
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;
  final bool Function(DateTime day)? isEnabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final d = days[i];
          final enabled = isEnabled?.call(d) ?? true;
          return DayChip(
            date: d,
            selected: sameDay(d, selected),
            enabled: enabled,
            onTap: () => onSelected(d),
          );
        },
      ),
    );
  }
}

class DayChip extends StatelessWidget {
  const DayChip({
    super.key,
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
        : (enabled ? Colors.white : AppColors.line);
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
            Text(dayName(date), style: TextStyle(fontSize: 11, color: textColor)),
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

/// Botón de un horario. Si está ocupado aparece tachado.
class SlotChip extends StatelessWidget {
  const SlotChip({
    super.key,
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

/// Círculo para elegir profesional ("Cualquiera" si [name] es null).
class ProChip extends StatelessWidget {
  const ProChip({
    super.key,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String? name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = name ?? 'Cualquiera';
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.action : Colors.transparent,
                width: 3,
              ),
            ),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: selected ? AppColors.teal : AppColors.aqua,
              child: name == null
                  ? const Icon(Icons.groups_outlined, color: Colors.white)
                  : Text(
                      label.isEmpty ? '?' : label[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

/// Horarios de un día agrupados por persona del personal.
/// Cada persona aparece con su turno y sus horarios; así el cliente sabe
/// quién lo atenderá en cada horario que elige.
class StaffSlotPicker extends StatelessWidget {
  const StaffSlotPicker({
    super.key,
    required this.business,
    required this.minutes,
    required this.day,
    required this.existing,
    required this.selectedTime,
    required this.selectedPro,
    required this.onSelected,
    this.ignoreId,
  });

  final Business business;
  final int minutes;
  final DateTime day;
  final List<Appointment> existing; // citas del día (para saber qué está ocupado)
  final DateTime? selectedTime;
  final String? selectedPro;
  final void Function(DateTime time, String professional) onSelected;
  final String? ignoreId; // al reprogramar, la cita que se está moviendo

  @override
  Widget build(BuildContext context) {
    final b = business;
    if (!b.isOpenOn(day)) {
      return const Text('El negocio no abre este día. Elige otra fecha.',
          style: TextStyle(color: AppColors.muted));
    }
    final now = DateTime.now();
    final working = b.team.where((m) => m.worksOn(day)).toList();
    if (working.isEmpty) {
      return const Text('Nadie del personal trabaja este día. Elige otra fecha.',
          style: TextStyle(color: AppColors.muted));
    }

    final groups = <Widget>[];
    for (final m in working) {
      final slots = slotsForMember(b, m, minutes, day);
      final free = [
        for (final t in slots)
          if (t.isAfter(now) &&
              isProfessionalFree(
                professional: m.name,
                start: t,
                minutes: minutes,
                existing: existing,
                ignoreId: ignoreId,
                now: now,
              ))
            t,
      ];
      groups.add(Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selectedPro == m.name ? AppColors.teal : AppColors.line,
              width: selectedPro == m.name ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: b.accent,
                    child: Text(
                      m.name.isEmpty ? '?' : m.name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Te atiende ${m.name}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Turno ${m.hoursText} · ${free.length} horarios libres',
                            style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (slots.isEmpty)
                const Text('Su turno no alcanza para este servicio.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in slots)
                      SlotChip(
                        label: hhmm(t),
                        selected: selectedPro == m.name && selectedTime == t,
                        enabled: free.contains(t),
                        onTap: () => onSelected(t, m.name),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...groups,
        const Text(
          'Los horarios tachados ya están ocupados o ya pasaron.',
          style: TextStyle(color: AppColors.muted, fontSize: 11),
        ),
      ],
    );
  }
}
