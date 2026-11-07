import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import '../../widgets/site_widgets.dart';
import '../business_setup_screen.dart';
import '../profile_screen.dart';
import 'payouts_screen.dart';

/// Apartado "Cuenta" del negocio: datos del negocio y
/// el botón para cambiar a la interfaz de cliente.
class BusinessProfileScreen extends StatelessWidget {
  const BusinessProfileScreen({super.key, required this.business});

  final Business business;

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context);
    final b = business;
    final closed = b.closedWeekdays.toList()..sort();

    Widget row(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: AppColors.teal),
              const SizedBox(width: 8),
              Expanded(child: Text(text)),
            ],
          ),
        );

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
        children: [
          AccountHeader(name: session.displayName, email: session.email, role: 'Negocio'),
          const SectionLabel('Mi negocio'),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    BusinessLogo(business: b, size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(b.categoryLabel,
                              style: const TextStyle(color: AppColors.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
                row(Icons.place_outlined, b.address),
                if (b.phone.isNotEmpty) row(Icons.phone_outlined, b.phone),
                row(Icons.schedule,
                    'Abre ${b.hoursText}${closed.isEmpty ? ' todos los días' : ' · cierra ${closed.map(weekdayShort).join(', ')}'}'),
                row(Icons.groups_outlined,
                    'Personal: ${b.team.map((m) => '${m.name} (${m.hoursText})').join(', ')}'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BusinessSetupScreen(existing: b),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar datos del negocio'),
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: () => session.businessTab = 1,
                  icon: const Icon(Icons.web_outlined),
                  label: const Text('Decorar mi sitio'),
                ),
              ],
            ),
          ),
          const SectionLabel('Cobros'),
          AppCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.greenSoft,
                child: Icon(Icons.payments_outlined, color: AppColors.green),
              ),
              title: const Text('Cobros y ventas',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Recibe anticipos y ventas con Stripe'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PayoutsScreen(business: b)),
              ),
            ),
          ),
          const SectionLabel('Cambiar de interfaz'),
          PrimaryButton(
            label: 'Cambiar a interfaz de cliente',
            onPressed: () => session.switchMode(AppMode.client),
          ),
          const SizedBox(height: 4),
          const Text(
            'Como cliente puedes buscar otros negocios y agendar tus propias citas. '
            'Tu negocio sigue recibiendo reservas.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          AppCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppColors.red),
              title: const Text('Cerrar sesión', style: TextStyle(color: AppColors.red)),
              onTap: () => session.signOut(),
            ),
          ),
        ],
      ),
    );
  }
}
