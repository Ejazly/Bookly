import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'booking_screen.dart';

/// Pantalla 3.8: Mis citas (próximas e historial).
class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  int _segment = 0; // 0 Próximas, 1 Historial

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final list = _segment == 0 ? state.upcoming : state.history;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        children: [
          const Text(
            'Mis citas',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Próximas')),
                ButtonSegment(value: 1, label: Text('Historial')),
              ],
              selected: {_segment},
              showSelectedIcon: false,
              onSelectionChanged: (values) =>
                  setState(() => _segment = values.first),
            ),
          ),
          const SizedBox(height: 14),
          if (list.isEmpty)
            _EmptyState(upcoming: _segment == 0)
          else
            for (final a in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AppointmentCard(
                  appointment: a,
                  upcoming: _segment == 0,
                ),
              ),
          if (_segment == 0 && list.isNotEmpty)
            const AppCard(
              color: Color(0xFFE6F0F2),
              child: Row(
                children: [
                  Icon(Icons.notifications_active_outlined,
                      color: AppColors.teal),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Te recordaremos tu cita 2 horas antes.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.upcoming});

  final bool upcoming;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.event_available, size: 48, color: AppColors.teal),
          const SizedBox(height: 10),
          Text(
            upcoming
                ? 'No tienes citas próximas'
                : 'Aún no tienes citas en tu historial',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          if (upcoming) ...[
            const SizedBox(height: 14),
            PrimaryButton(
              label: 'Explorar negocios',
              onPressed: () => AppScope.read(context).tab = 0,
            ),
          ],
        ],
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.appointment, required this.upcoming});

  final Appointment appointment;
  final bool upcoming;

  Future<void> _cancel(BuildContext context) async {
    final state = AppScope.read(context);
    final a = appointment;
    final refundable = state.isRefundable(a);
    final ok = await confirmDialog(
      context,
      title: '¿Cancelar cita?',
      message: refundable
          ? 'Faltan más de 24 horas para tu cita, así que se te reembolsará '
              'el anticipo de ${money2(a.depositPaid)}.'
          : 'Faltan menos de 24 horas para tu cita. Según la política, '
              'el anticipo de ${money2(a.depositPaid)} no es reembolsable.',
      confirmLabel: 'Cancelar cita',
      color: AppColors.red,
    );
    if (!ok) return;
    state.cancel(a);
    if (context.mounted) {
      showMessage(
        context,
        refundable
            ? 'Cita cancelada. Tu anticipo será reembolsado.'
            : 'Cita cancelada.',
      );
    }
  }

  void _reschedule(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingScreen(
          business: appointment.business,
          service: appointment.service,
          rescheduling: appointment,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = appointment;

    final StatusBadge badge;
    if (a.isCancelled) {
      badge = const StatusBadge('Cancelada',
          color: AppColors.red, background: AppColors.redSoft);
    } else if (upcoming) {
      badge = const StatusBadge('Confirmada');
    } else {
      badge = const StatusBadge('Completada',
          color: AppColors.muted, background: AppColors.light);
    }

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  a.service.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              badge,
            ],
          ),
          const SizedBox(height: 4),
          Text('${a.business.name} · con ${a.professional.name}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 16, color: AppColors.teal),
              const SizedBox(width: 6),
              Text('${shortDate(a.start)} · ${hhmm(a.start)}'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Anticipo pagado ${money2(a.depositPaid)}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              Text('Resta ${money2(a.remaining)}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
          if (a.note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Nota: ${a.note}',
                style: const TextStyle(fontSize: 12, color: AppColors.ink)),
          ],
          if (upcoming) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _reschedule(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.teal,
                      side: const BorderSide(color: AppColors.teal),
                    ),
                    child: const Text('Reprogramar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _cancel(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.red,
                      side: const BorderSide(color: Color(0xFFE8B4B4)),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
