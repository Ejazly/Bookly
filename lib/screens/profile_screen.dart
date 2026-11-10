import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import 'wallet_screen.dart';

/// Pestaña Perfil del cliente. Desde aquí se cambia a la interfaz de negocio.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context);
    final profile = session.profile;
    final hasBusiness = profile?.isBusiness ?? false;
    final business = session.myBusiness;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
        children: [
          AccountHeader(name: session.displayName, email: session.email, role: 'Cliente'),
          const SectionLabel('Cambiar de interfaz'),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: AppColors.teal,
                      child: Icon(Icons.storefront, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasBusiness && business != null
                                ? business.name
                                : '¿Tienes un negocio?',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            hasBusiness
                                ? 'Administra tu agenda, inventario y publicaciones.'
                                : 'Regístralo y recibe citas desde Bookly.',
                            style: const TextStyle(color: AppColors.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                PrimaryButton(
                  label: hasBusiness ? 'Ir a mi negocio' : 'Registrar mi negocio',
                  onPressed: () => session.switchMode(AppMode.business),
                ),
              ],
            ),
          ),
          const SectionLabel('Cuenta'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.mail_outline),
                  title: const Text('Avisos de citas'),
                  subtitle: Text('Se envían a ${session.email}'),
                ),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: const Text('Billetera'),
                  subtitle: const Text('Formas de pago, pagos y compras'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WalletScreen()),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.event_note_outlined),
                  title: const Text('Mis citas'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => session.clientTab = 2,
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.red),
                  title: const Text('Cerrar sesión',
                      style: TextStyle(color: AppColors.red)),
                  onTap: () => session.signOut(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Encabezado con la inicial, el nombre y el Gmail vinculado.
class AccountHeader extends StatelessWidget {
  const AccountHeader({
    super.key,
    required this.name,
    required this.email,
    required this.role,
  });

  final String name;
  final String email;
  final String role;

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    return Column(
      children: [
        CircleAvatar(
          radius: 42,
          backgroundColor: AppColors.teal,
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified, size: 16, color: AppColors.green),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                email,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        StatusBadge(role, color: AppColors.teal, background: AppColors.mist),
      ],
    );
  }
}
