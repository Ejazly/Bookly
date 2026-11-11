import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/account_service.dart';
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
                ListTile(
                  leading: const Icon(Icons.delete_forever_outlined, color: AppColors.red),
                  title: const Text('Borrar mi cuenta',
                      style: TextStyle(color: AppColors.red)),
                  subtitle: const Text('Elimina tus datos de forma permanente'),
                  onTap: () => confirmAndDeleteAccount(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Doble confirmación (aviso + escribir BORRAR), borra la cuenta en el
/// servidor y cierra la sesión. También la usa el panel del negocio.
Future<void> confirmAndDeleteAccount(BuildContext context) async {
  final session = AppScope.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final controller = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('¿Borrar tu cuenta?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Se borrarán para siempre tu perfil, tu negocio (si tienes), tus '
              'publicaciones y tus tarjetas guardadas. No se puede deshacer.\n\n'
              'Para continuar escribe BORRAR.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: 'BORRAR'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: controller.text.trim() == 'BORRAR'
                ? () => Navigator.pop(ctx, true)
                : null,
            child: const Text('Borrar cuenta', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  if (confirmed != true || !context.mounted) return;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  try {
    await AccountService.deleteAccount();
  } on AccountException catch (e) {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return;
  }
  if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  try {
    await session.signOut();
  } catch (_) {
    // La cuenta ya no existe; si cerrar sesión falla, el AuthGate la detectará.
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
