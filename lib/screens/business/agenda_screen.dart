import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/database.dart';
import '../../services/email_service.dart';
import '../../services/payments_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import '../../widgets/schedule_widgets.dart';
import 'add_client_screen.dart';

enum _View { day, upcoming }

enum _Origin { all, app, business }

/// Apartado Agenda del negocio. Aquí llegan:
///   - los clientes que reservaron en la app pagando el anticipo del 25 %
///   - las personas que el negocio agrega a mano (con o sin anticipo)
/// Todo se guarda en la colección `appointments` de Firestore y la pantalla
/// se actualiza sola cuando alguien agenda.
class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key, required this.business});

  final Business business;

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  late final List<DateTime> _days = nextDays(DateTime.now(), 21);
  late DateTime _day = _days.first;
  late Stream<List<Appointment>> _dayStream =
      Database.instance.appointmentsForDay(widget.business.id, _day);
  late final Stream<List<Appointment>> _upcomingStream =
      Database.instance.upcomingForBusiness(widget.business.id);

  _View _view = _View.day;
  _Origin _origin = _Origin.all;

  void _selectDay(DateTime d) {
    setState(() {
      _day = d;
      _dayStream = Database.instance.appointmentsForDay(widget.business.id, d);
    });
  }

  void _addPerson() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddClientScreen(business: widget.business, initialDay: _day),
      ),
    );
  }

  bool _matchesOrigin(Appointment a) => switch (_origin) {
        _Origin.all => true,
        _Origin.app => !a.createdByBusiness,
        _Origin.business => a.createdByBusiness,
      };

  Future<void> _cancel(Appointment a) async {
    final contactNote = a.clientEmail.isNotEmpty
        ? 'Le avisaremos por correo a ${a.clientEmail}.'
        : 'Esta persona no tiene correo registrado; avísale por teléfono.';
    final refundNote = a.depositPaid > 0 && !a.createdByBusiness
        ? '\nSe le devolverá el anticipo de ${money2(a.depositPaid)} que pagó en la app.'
        : '';
    final ok = await confirmDialog(
      context,
      title: '¿Cancelar la cita de ${a.clientName}?',
      message: '${a.serviceName} · ${shortDate(a.start)} ${hhmm(a.start)}.\n$contactNote$refundNote',
      confirmLabel: 'Cancelar cita',
      color: AppColors.red,
    );
    if (!ok) return;
    try {
      final refunded = await Payments.cancelAppointment(a.id);
      final sent = await EmailService.notifyCancelledByBusiness(a);
      if (mounted) {
        showMessage(
          context,
          [
            'Cita cancelada.',
            if (refunded > 0) 'Se reembolsaron ${money2(refunded)} al cliente.',
            if (sent) 'Se le avisó por correo.',
          ].join(' '),
        );
      }
    } on PaymentException catch (e) {
      if (mounted) showMessage(context, e.message);
    }
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0x1FFFFFFF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(label, style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _originChip(String label, _Origin value) {
    final selected = _origin == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        selectedColor: AppColors.teal,
        backgroundColor: Colors.white,
        labelStyle: TextStyle(color: selected ? Colors.white : AppColors.teal),
        onSelected: (_) => setState(() => _origin = value),
      ),
    );
  }

  Widget _tile(Appointment a) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _AgendaTile(appointment: a, onCancel: () => _cancel(a)),
      );

  /// Lista de un día.
  List<Widget> _dayContent(List<Appointment> active, List<Appointment> cancelled) {
    final b = widget.business;
    if (!b.isOpenOn(_day) && active.isEmpty) {
      return const [
        EmptyMessage(icon: Icons.event_busy, text: 'Tu negocio no abre este día.'),
      ];
    }
    return [
      if (active.isEmpty)
        EmptyMessage(
          icon: Icons.event_available,
          text: 'No hay citas para el ${longDate(_day)}.',
          action: OutlinedButton.icon(
            onPressed: _addPerson,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Agregar una persona'),
          ),
        )
      else
        for (final a in active) _tile(a),
      if (cancelled.isNotEmpty) ...[
        const SectionLabel('Canceladas'),
        for (final a in cancelled)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '${hhmm(a.start)} · ${a.clientName} · ${a.serviceName}',
              style: const TextStyle(
                color: AppColors.muted,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ),
      ],
    ];
  }

  /// Próximas citas agrupadas por día.
  List<Widget> _upcomingContent(List<Appointment> list) {
    if (list.isEmpty) {
      return [
        EmptyMessage(
          icon: Icons.event_available,
          text: 'No tienes citas próximas.',
          action: OutlinedButton.icon(
            onPressed: _addPerson,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Agregar una persona'),
          ),
        ),
      ];
    }
    final widgets = <Widget>[];
    DateTime? current;
    for (final a in list) {
      if (current == null || !sameDay(current, a.start)) {
        current = a.start;
        widgets.add(SectionLabel(longDate(a.start)));
      }
      widgets.add(_tile(a));
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.business;
    final top = MediaQuery.of(context).padding.top;
    final isDay = _view == _View.day;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPerson,
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Agregar persona'),
      ),
      body: StreamBuilder<List<Appointment>>(
        // Cada vista tiene su propia consulta a la base de datos.
        key: ValueKey(_view),
        stream: isDay ? _dayStream : _upcomingStream,
        builder: (context, snapshot) {
          final all = snapshot.data ?? const <Appointment>[];
          final now = DateTime.now();
          // Confirmadas, o apartadas mientras el cliente termina de pagar.
          final active = all.where((a) => a.blocksSlot(now) && _matchesOrigin(a)).toList();
          // Los pagos que no se completaron no se muestran (nunca fueron citas).
          final cancelled = all
              .where((a) =>
                  (a.status == AppointmentStatus.cancelada ||
                      a.status == AppointmentStatus.reembolsada) &&
                  _matchesOrigin(a))
              .toList();
          final confirmed = active.where((a) => !a.isPending).toList();
          final withDeposit = confirmed.where((a) => a.depositPaid > 0).length;
          final deposits = confirmed.fold<double>(0, (sum, a) => sum + a.depositPaid);
          final pending = confirmed.fold<double>(0, (sum, a) => sum + a.remaining);

          return ListView(
            padding: const EdgeInsets.only(bottom: 90),
            children: [
              Container(
                color: AppColors.deep,
                padding: EdgeInsets.fromLTRB(18, top + 14, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('AGENDA',
                        style: TextStyle(color: Color(0xBFFFFFFF), fontSize: 11)),
                    Text(
                      b.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _stat('${active.length}', isDay ? 'Citas del día' : 'Citas próximas'),
                        const SizedBox(width: 8),
                        _stat('$withDeposit · ${money(deposits)}', 'Con anticipo'),
                        const SizedBox(width: 8),
                        _stat(money(pending), 'Por cobrar'),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<_View>(
                      segments: const [
                        ButtonSegment(
                          value: _View.day,
                          icon: Icon(Icons.today_outlined),
                          label: Text('Por día'),
                        ),
                        ButtonSegment(
                          value: _View.upcoming,
                          icon: Icon(Icons.view_list_outlined),
                          label: Text('Próximas'),
                        ),
                      ],
                      selected: {_view},
                      onSelectionChanged: (v) => setState(() => _view = v.first),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _originChip('Todas', _Origin.all),
                          _originChip('Reservas con anticipo', _Origin.app),
                          _originChip('Agregadas por mí', _Origin.business),
                        ],
                      ),
                    ),
                    if (isDay) ...[
                      const SizedBox(height: 10),
                      Text(monthYear(_day),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      DaySelector(days: _days, selected: _day, onSelected: _selectDay),
                    ],
                    const SizedBox(height: 14),
                    if (streamStatus(snapshot) case final status?)
                      status
                    else if (isDay)
                      ..._dayContent(active, cancelled)
                    else
                      ..._upcomingContent(active),
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

class _AgendaTile extends StatelessWidget {
  const _AgendaTile({required this.appointment, required this.onCancel});

  final Appointment appointment;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final contact = [
      if (a.clientEmail.isNotEmpty) a.clientEmail,
      if (a.clientPhone.isNotEmpty) a.clientPhone,
    ].join(' · ');

    final StatusBadge origin = a.createdByBusiness
        ? const StatusBadge('Agregada por ti',
            color: AppColors.blue, background: Color(0xFFE3ECF7))
        : const StatusBadge('Reservó en la app');
    final StatusBadge deposit = a.isPending
        ? const StatusBadge('Pagando anticipo…',
            color: Color(0xFFB57511), background: AppColors.amberSoft)
        : a.depositPaid > 0
            ? StatusBadge('Anticipo ${money2(a.depositPaid)}')
            : const StatusBadge('Sin anticipo',
                color: Color(0xFFB57511), background: AppColors.amberSoft);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hhmm(a.start),
                    style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.bold)),
                Text(hhmm(a.end), style: const TextStyle(color: AppColors.muted, fontSize: 11)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.clientName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('${a.serviceName} · con ${a.professional}',
                    style: const TextStyle(fontSize: 13)),
                if (contact.isNotEmpty)
                  Text(contact, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                if (a.note.isNotEmpty)
                  Text('Nota: ${a.note}',
                      style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    origin,
                    deposit,
                    StatusBadge('Por cobrar ${money2(a.remaining)}',
                        color: AppColors.muted, background: AppColors.light),
                  ],
                ),
              ],
            ),
          ),
          if (a.isPending)
            const SizedBox(width: 12)
          else
          PopupMenuButton<String>(
            tooltip: 'Opciones',
            onSelected: (v) {
              if (v == 'cancel') onCancel();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'cancel', child: Text('Cancelar cita')),
            ],
          ),
        ],
      ),
    );
  }
}
