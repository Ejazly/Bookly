import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'login_screen.dart';

/// Pantalla 3.9: Panel del negocio.
/// Muestra la agenda real del negocio (incluye las citas que se agendan
/// desde la app del cliente).
class BusinessPanelScreen extends StatefulWidget {
  const BusinessPanelScreen({super.key});

  @override
  State<BusinessPanelScreen> createState() => _BusinessPanelScreenState();
}

class _BusinessPanelScreenState extends State<BusinessPanelScreen> {
  int _dayOffset = 0; // 0 = hoy

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
            Text(label,
                style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _admin(IconData icon, String label, Color color) {
    return AppCard(
      onTap: () => showSoon(context),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final business = state.businesses.first; // negocio de demostración
    final today = dateOnly(state.now);
    final day = DateTime(today.year, today.month, today.day + _dayOffset);
    final agenda = state.agendaFor(business, day);
    final deposits = agenda.fold<double>(0, (sum, a) => sum + a.depositPaid);
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            color: AppColors.deep,
            padding: EdgeInsets.fromLTRB(18, top + 12, 8, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PANEL DEL NEGOCIO',
                            style: TextStyle(
                                color: Color(0xBFFFFFFF), fontSize: 11),
                          ),
                          Text(
                            business.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar sesión',
                      icon: const Icon(Icons.logout, color: Colors.white),
                      onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Row(
                    children: [
                      _stat('${agenda.length}', 'Citas del día'),
                      const SizedBox(width: 8),
                      _stat(money(deposits), 'Anticipos'),
                      const SizedBox(width: 8),
                      _stat(business.rating.toStringAsFixed(1), 'Calificación'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Agenda',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (var i = 0; i < 7; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(i == 0
                                ? 'Hoy'
                                : shortDate(DateTime(
                                    today.year, today.month, today.day + i))),
                            selected: _dayOffset == i,
                            showCheckmark: false,
                            selectedColor: AppColors.teal,
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(
                              color: _dayOffset == i
                                  ? Colors.white
                                  : AppColors.teal,
                            ),
                            onSelected: (_) => setState(() => _dayOffset = i),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (!business.isOpenOn(day))
                  const Text('El negocio no abre este día.',
                      style: TextStyle(color: AppColors.muted))
                else if (agenda.isEmpty)
                  const Text('No hay citas para este día.',
                      style: TextStyle(color: AppColors.muted)),
                for (final a in agenda)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 52,
                            child: Text(
                              hhmm(a.start),
                              style: const TextStyle(
                                color: AppColors.teal,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a.service.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                Text(
                                  '${a.clientName} · ${a.professional.name}',
                                  style: const TextStyle(
                                      color: AppColors.muted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          a.fromCurrentUser
                              ? const StatusBadge('Nueva · 25 %',
                                  color: AppColors.blue,
                                  background: Color(0xFFE3ECF7))
                              : const StatusBadge('Pagado 25 %'),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                const Text(
                  'Administrar',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.5,
                  children: [
                    _admin(Icons.list_alt, 'Servicios y precios', AppColors.teal),
                    _admin(Icons.schedule, 'Horarios', AppColors.teal),
                    _admin(Icons.local_offer_outlined, 'Promociones',
                        AppColors.green),
                    _admin(Icons.video_call_outlined, 'Subir video',
                        AppColors.blue),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
