import 'package:flutter/material.dart';

import '../logic/schedule.dart';
import '../models/models.dart';
import '../services/database.dart';
import '../services/email_service.dart';
import '../services/payments_service.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'booking_screen.dart';

/// Mis citas (cliente): próximas e historial.
/// Incluye las citas que un negocio le agregó con su Gmail.
class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  int _segment = 0; // 0 Próximas, 1 Historial
  Stream<List<Appointment>>? _stream;
  String? _streamEmail;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final email = AppScope.read(context).email;
    if (email != _streamEmail) {
      _streamEmail = email;
      _stream = Database.instance.appointmentsForClient(email);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<Appointment>>(
        stream: _stream,
        builder: (context, snapshot) {
          final status = streamStatus(snapshot);
          final split = splitAppointments(
            snapshot.data ?? const <Appointment>[],
            DateTime.now(),
          );
          final list = _segment == 0 ? split.upcoming : split.history;

          return ListView(
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
                  segments: [
                    ButtonSegment(
                        value: 0, label: Text('Próximas (${split.upcoming.length})')),
                    const ButtonSegment(value: 1, label: Text('Historial')),
                  ],
                  selected: {_segment},
                  showSelectedIcon: false,
                  onSelectionChanged: (values) =>
                      setState(() => _segment = values.first),
                ),
              ),
              const SizedBox(height: 14),
              if (status != null)
                status
              else if (list.isEmpty)
                EmptyMessage(
                  icon: Icons.event_available,
                  text: _segment == 0
                      ? 'No tienes citas próximas'
                      : 'Aún no tienes citas en tu historial',
                  action: _segment == 0
                      ? PrimaryButton(
                          label: 'Explorar negocios',
                          onPressed: () => AppScope.read(context).clientTab = 0,
                        )
                      : null,
                )
              else
                for (final a in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AppointmentCard(
                      key: ValueKey(a.id),
                      appointment: a,
                      upcoming: _segment == 0,
                    ),
                  ),
              if (_segment == 0 && list.isNotEmpty)
                const AppCard(
                  color: Color(0xFFE6F0F2),
                  child: Row(
                    children: [
                      Icon(Icons.mark_email_read_outlined, color: AppColors.teal),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'El negocio recibe un correo cada vez que agendas, cancelas o cambias una cita.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AppointmentCard extends StatefulWidget {
  const _AppointmentCard({super.key, required this.appointment, required this.upcoming});

  final Appointment appointment;
  final bool upcoming;

  @override
  State<_AppointmentCard> createState() => _AppointmentCardState();
}

class _AppointmentCardState extends State<_AppointmentCard> {
  bool _busy = false;

  Future<void> _cancel() async {
    final a = widget.appointment;
    final refundable = isRefundable(a, DateTime.now());
    final depositText = money2(a.depositPaid);
    final ok = await confirmDialog(
      context,
      title: '¿Cancelar cita?',
      message: a.depositPaid == 0
          ? 'Se le avisará al negocio por correo.'
          : refundable
              ? 'Faltan más de 24 horas para tu cita, así que se te reembolsará el anticipo de $depositText.'
              : 'Faltan menos de 24 horas para tu cita. Según la política, el anticipo de $depositText no es reembolsable.',
      confirmLabel: 'Cancelar cita',
      color: AppColors.red,
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      // El servidor revisa la política de 24 h y hace el reembolso en Stripe.
      final refunded = await Payments.cancelAppointment(a.id);
      await EmailService.notifyCancelledByClient(a);
      if (mounted) {
        showMessage(
          context,
          refunded > 0
              ? 'Cita cancelada. Se te devolvieron ${money2(refunded)} a tu tarjeta.'
              : 'Cita cancelada.',
        );
      }
    } on PaymentException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Cita apartada que todavía no se paga: se libera el horario.
  Future<void> _cancelPending() async {
    setState(() => _busy = true);
    try {
      await Payments.cancelPending(isOrder: false, id: widget.appointment.id);
      if (mounted) showMessage(context, 'Se liberó el horario. No se hizo ningún cargo.');
    } on PaymentException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reschedule() async {
    final a = widget.appointment;
    setState(() => _busy = true);
    try {
      final b = await Database.instance.getBusiness(a.businessId);
      if (!mounted) return;
      if (b == null) {
        showMessage(context, 'El negocio ya no está disponible.');
        return;
      }
      final service = Item(
        id: a.itemId,
        kind: ItemKind.servicio,
        name: a.serviceName,
        price: a.price,
        minutes: a.minutes,
      );
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BookingScreen(business: b, service: service, rescheduling: a),
        ),
      );
    } catch (e) {
      if (mounted) showMessage(context, 'No se pudo abrir la agenda: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;

    final StatusBadge badge;
    if (a.isCancelled) {
      badge = StatusBadge(a.status.label,
          color: AppColors.red, background: AppColors.redSoft);
    } else if (a.isPending) {
      badge = const StatusBadge('Esperando pago',
          color: Color(0xFFB57511), background: AppColors.amberSoft);
    } else if (widget.upcoming) {
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
                  a.serviceName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              badge,
            ],
          ),
          const SizedBox(height: 4),
          Text('${a.businessName} · con ${a.professional}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.teal),
              const SizedBox(width: 6),
              Text('${shortDate(a.start)} · ${hhmm(a.start)}'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                a.createdByBusiness
                    ? 'Agendada por el negocio'
                    : a.isPending
                        ? 'Anticipo sin pagar'
                        : a.refundedCents > 0
                            ? 'Reembolsado ${money2(fromCents(a.refundedCents))}'
                            : 'Anticipo pagado ${money2(a.depositPaid)}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              Text('Resta ${money2(a.remaining)}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
          if (a.note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Nota: ${a.note}', style: const TextStyle(fontSize: 12)),
          ],
          if (widget.upcoming && a.isPending) ...[
            const SizedBox(height: 12),
            if (_busy)
              const LinearProgressIndicator()
            else
              OutlinedButton(
                onPressed: _cancelPending,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.red,
                  side: const BorderSide(color: Color(0xFFE8B4B4)),
                ),
                child: const Text('Cancelar apartado'),
              ),
          ] else if (widget.upcoming) ...[
            const SizedBox(height: 12),
            if (_busy)
              const LinearProgressIndicator()
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _reschedule,
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
                      onPressed: _cancel,
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
