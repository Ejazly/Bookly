import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import 'login_screen.dart';

/// Pestaña Perfil del cliente.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notifications = true;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final name = state.userName.isEmpty ? 'Ana' : state.userName;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
        children: [
          Center(
            child: CircleAvatar(
              radius: 42,
              backgroundColor: AppColors.teal,
              child: Text(
                name[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Center(
            child: Text(
              'Cliente · ${state.myAppointments.length} citas agendadas',
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
          const SizedBox(height: 20),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Mis datos'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showSoon(context),
                ),
                ListTile(
                  leading: const Icon(Icons.credit_card),
                  title: const Text('Métodos de pago'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showSoon(context),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_none),
                  title: const Text('Recordatorios de citas'),
                  value: _notifications,
                  activeColor: AppColors.teal,
                  onChanged: (v) => setState(() => _notifications = v),
                ),
                ListTile(
                  leading: const Icon(Icons.favorite_border),
                  title: const Text('Negocios favoritos'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showSoon(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppColors.red),
              title: const Text('Cerrar sesión',
                  style: TextStyle(color: AppColors.red)),
              onTap: () {
                state.tab = 0;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
