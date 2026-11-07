import 'package:flutter/material.dart';

import '../logic/schedule.dart';
import '../models/models.dart';
import '../services/database.dart';
import '../services/email_service.dart';
import '../services/payments_service.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/schedule_widgets.dart';
import 'payment_screen.dart';

/// Agendar cita (cliente). También se usa para reprogramar una cita
/// existente cuando [rescheduling] no es null.
///
/// Los horarios ocupados se leen en tiempo real de `businesses/{id}/busy`
/// (sin datos de otros clientes): si otra persona agenda mientras tienes la
/// pantalla abierta, el horario se tacha. El servidor lo vuelve a revisar
/// al apartar o reprogramar.
class BookingScreen extends StatefulWidget {
  const BookingScreen({
    super.key,
    required this.business,
    required this.service,
    this.rescheduling,
  });

  final Business business;
  final Item service;
  final Appointment? rescheduling;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  static const int _daysToShow = 21;

  final _note = TextEditingController();
  late final List<DateTime> _days = nextDays(DateTime.now(), _daysToShow);
  late DateTime _day = _initialDay();
  late Stream<List<Appointment>> _stream =
      Database.instance.busyForDay(widget.business.id, _day);
  DateTime? _time;
  String? _pro; // quién atiende en el horario elegido
  bool _saving = false;

  DateTime _initialDay() {
    final r = widget.rescheduling;
    if (r != null && !r.start.isBefore(_days.first)) return dateOnly(r.start);
    final now = DateTime.now();
    // Primer día abierto que todavía tenga horarios por delante.
    for (final d in _days) {
      final hasSlot = widget.business.team.any((m) =>
          slotsForMember(widget.business, m, widget.service.minutes, d)
              .any((t) => t.isAfter(now)));
      if (hasSlot) return d;
    }
    return _days.first;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _selectDay(DateTime d) {
    setState(() {
      _day = d;
      _time = null;
      _pro = null;
      _stream = Database.instance.busyForDay(widget.business.id, d);
    });
  }

  Future<void> _continue() async {
    final t = _time;
    if (t == null) return;
    final r = widget.rescheduling;

    if (r == null) {
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
      return;
    }

    setState(() => _saving = true);
    try {
      final pro = await Payments.reschedule(
        appointmentId: r.id,
        start: t,
        professional: _pro,
      );
      await EmailService.notifyRescheduled(r, r.copyWith(start: t, professional: pro));
      if (!mounted) return;
      showMessage(context, 'Cita reprogramada para el ${shortDate(t)} a las ${hhmm(t)} con $pro.');
      Navigator.of(context).pop();
    } on PaymentException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.business;
    final s = widget.service;
    final isReschedule = widget.rescheduling != null;
    final selected = _time;

    return Scaffold(
      appBar: AppBar(title: Text(isReschedule ? 'Reprogramar cita' : 'Agendar cita')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        children: [
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
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('${b.name} · ${durationText(s.minutes)}',
                          style: const TextStyle(color: AppColors.muted, fontSize: 12)),
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

          SectionLabel(monthYear(_day)),
          DaySelector(
            days: _days,
            selected: _day,
            onSelected: _selectDay,
            isEnabled: b.isOpenOn,
          ),

          const SectionLabel('Elige horario y quién te atiende'),
          StreamBuilder<List<Appointment>>(
            stream: _stream,
            builder: (context, snapshot) {
              final status = streamStatus(snapshot);
              if (status != null) return status;
              return StaffSlotPicker(
                business: b,
                minutes: s.minutes,
                day: _day,
                existing: snapshot.data!,
                selectedTime: _time,
                selectedPro: _pro,
                ignoreId: widget.rescheduling?.id,
                onSelected: (t, pro) => setState(() {
                  _time = t;
                  _pro = pro;
                }),
              );
            },
          ),

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
                  Expanded(
                    child: Text(
                      selected == null
                          ? 'Elige un horario'
                          : '${shortDate(selected)} · ${hhmm(selected)} · con ${_pro ?? ''}',
                      style: const TextStyle(color: AppColors.muted),
                    ),
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
                loading: _saving,
                onPressed: selected == null ? null : _continue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
