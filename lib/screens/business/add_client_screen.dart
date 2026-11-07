import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/database.dart';
import '../../services/email_service.dart';
import '../../services/payments_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import '../../widgets/schedule_widgets.dart';

enum _Deposit { none, quarter, other }

/// El negocio agrega a una persona a su agenda (por ejemplo, alguien que
/// llamó por teléfono o llegó al local). Puede registrar si dejó anticipo.
class AddClientScreen extends StatefulWidget {
  const AddClientScreen({super.key, required this.business, required this.initialDay});

  final Business business;
  final DateTime initialDay;

  @override
  State<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends State<AddClientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();
  final _otherDeposit = TextEditingController();

  late final List<DateTime> _days = nextDays(DateTime.now(), 21);
  late DateTime _day = dateOnly(widget.initialDay);
  late Stream<List<Appointment>> _dayStream =
      Database.instance.appointmentsForDay(widget.business.id, _day);
  late final Stream<List<Item>> _itemsStream =
      Database.instance.itemsStream(widget.business.id);

  Item? _service;
  String? _pro; // quién atiende en el horario elegido
  DateTime? _time;
  _Deposit _deposit = _Deposit.none;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _note.dispose();
    _otherDeposit.dispose();
    super.dispose();
  }

  void _selectDay(DateTime d) {
    setState(() {
      _day = d;
      _time = null;
      _pro = null;
      _dayStream = Database.instance.appointmentsForDay(widget.business.id, d);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final service = _service;
    final time = _time;
    if (service == null) {
      showMessage(context, 'Elige el servicio.');
      return;
    }
    if (time == null) {
      showMessage(context, 'Elige el horario.');
      return;
    }
    final double deposit;
    switch (_deposit) {
      case _Deposit.none:
        deposit = 0;
      case _Deposit.quarter:
        deposit = service.deposit;
      case _Deposit.other:
        final amount = double.tryParse(_otherDeposit.text.trim());
        if (amount == null || amount < 0 || amount > service.price) {
          showMessage(context, 'Escribe un anticipo entre \$0 y ${money(service.price)}.');
          return;
        }
        deposit = amount;
    }
    setState(() => _saving = true);
    try {
      // El servidor revisa el horario y guarda la cita (nadie más puede
      // escribir citas directamente en la base de datos).
      final pro = await Payments.addManualAppointment(
        itemId: service.id,
        start: time,
        professional: _pro,
        clientName: _name.text.trim(),
        clientEmail: _email.text.trim().toLowerCase(),
        clientPhone: _phone.text.trim(),
        note: _note.text.trim(),
        depositPaid: deposit,
      );
      final b = widget.business;
      final a = Appointment(
        id: '',
        businessId: b.id,
        businessName: b.name,
        ownerEmail: b.ownerEmail,
        itemId: service.id,
        serviceName: service.name,
        minutes: service.minutes,
        price: service.price,
        depositPaid: deposit,
        professional: pro,
        start: time,
        clientName: _name.text.trim(),
        clientEmail: _email.text.trim().toLowerCase(),
        clientPhone: _phone.text.trim(),
        note: _note.text.trim(),
        createdByBusiness: true,
      );
      final sent = await EmailService.notifyClientAdded(a);
      if (!mounted) return;
      showMessage(
        context,
        sent
            ? 'Cita agregada. Le enviamos la confirmación a ${a.clientEmail}.'
            : 'Cita agregada para ${a.clientName} el ${shortDate(a.start)} a las ${hhmm(a.start)}.',
      );
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
    return Scaffold(
      appBar: AppBar(title: const Text('Agregar persona a la agenda')),
      body: StreamBuilder<List<Item>>(
        stream: _itemsStream,
        builder: (context, itemsSnap) {
          final services =
              (itemsSnap.data ?? const <Item>[]).where((i) => i.isService && i.active).toList();
          // Si el servicio elegido se borró, se quita la selección.
          final selected = _service == null
              ? null
              : services.where((s) => s.id == _service!.id).firstOrNull;

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
              children: [
                const SectionLabel('Datos de la persona'),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: fieldDecoration('Nombre', icon: Icons.person_outline),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Escribe el nombre del cliente' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: fieldDecoration('Correo (opcional)', icon: Icons.mail_outline),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return null;
                    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)
                        ? null
                        : 'Correo no válido';
                  },
                ),
                const SizedBox(height: 4),
                const Text(
                  'Si escribes su Gmail, le llega la confirmación y ve la cita en su app.',
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: fieldDecoration('Teléfono (opcional)', icon: Icons.phone_outlined),
                ),

                const SectionLabel('Servicio'),
                if (itemsSnap.hasError)
                  Text('No se pudieron cargar los servicios: ${itemsSnap.error}')
                else if (!itemsSnap.hasData)
                  const LinearProgressIndicator()
                else if (services.isEmpty)
                  const AppCard(
                    color: AppColors.amberSoft,
                    child: Text(
                      'Todavía no tienes servicios. Agrégalos en la pestaña Inventario '
                      '(tipo "Servicio") para poder agendar.',
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: selected?.id,
                    decoration: fieldDecoration('Elige el servicio'),
                    items: [
                      for (final s in services)
                        DropdownMenuItem(
                          value: s.id,
                          child: Text('${s.name} · ${durationText(s.minutes)} · ${money(s.price)}'),
                        ),
                    ],
                    onChanged: (id) => setState(() {
                      _service = services.firstWhere((s) => s.id == id);
                      _time = null;
                    }),
                  ),

                SectionLabel('Día · ${monthYear(_day)}'),
                DaySelector(
                  days: _days,
                  selected: _day,
                  onSelected: _selectDay,
                  isEnabled: b.isOpenOn,
                ),

                const SectionLabel('Horario y quién atiende'),
                if (selected == null)
                  const Text('Primero elige el servicio.',
                      style: TextStyle(color: AppColors.muted))
                else
                  StreamBuilder<List<Appointment>>(
                    stream: _dayStream,
                    builder: (context, snap) {
                      final status = streamStatus(snap);
                      if (status != null) return status;
                      return StaffSlotPicker(
                        business: b,
                        minutes: selected.minutes,
                        day: _day,
                        existing: snap.data!,
                        selectedTime: _time,
                        selectedPro: _pro,
                        onSelected: (t, pro) => setState(() {
                          _time = t;
                          _pro = pro;
                        }),
                      );
                    },
                  ),

                const SectionLabel('Anticipo'),
                if (selected == null)
                  const Text('Primero elige el servicio.',
                      style: TextStyle(color: AppColors.muted))
                else ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in _Deposit.values)
                        ChoiceChip(
                          label: Text(switch (option) {
                            _Deposit.none => 'Sin anticipo',
                            _Deposit.quarter => '25 % (${money2(selected.deposit)})',
                            _Deposit.other => 'Otro monto',
                          }),
                          selected: _deposit == option,
                          showCheckmark: false,
                          selectedColor: AppColors.teal,
                          labelStyle: TextStyle(
                            color: _deposit == option ? Colors.white : AppColors.teal,
                          ),
                          onSelected: (_) => setState(() => _deposit = option),
                        ),
                    ],
                  ),
                  if (_deposit == _Deposit.other) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _otherDeposit,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: fieldDecoration('Monto recibido', icon: Icons.attach_money),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'Costo del servicio: ${money2(selected.price)}. '
                    'Registra aquí si la persona ya dejó un anticipo (efectivo o transferencia).',
                    style: const TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                ],

                const SectionLabel('Nota (opcional)'),
                TextField(
                  controller: _note,
                  maxLines: 2,
                  decoration: fieldDecoration('Ej. viene con su hijo'),
                ),
                const SizedBox(height: 22),
                PrimaryButton(
                  label: 'Agregar a la agenda',
                  loading: _saving,
                  onPressed: _save,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
