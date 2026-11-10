import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';

/// Registro: aparece la primera vez que una cuenta de Google entra a Bookly.
/// La persona elige qué perfil le interesa: Cliente, Negocio o los dos.
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  final _name = TextEditingController();
  bool _client = true;
  bool _business = false;
  bool _saving = false;
  bool _filled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_filled) return;
    _filled = true;
    _name.text = AppScope.read(context).displayName;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_name.text.trim().isEmpty) {
      showMessage(context, 'Escribe tu nombre.');
      return;
    }
    if (!_client && !_business) {
      showMessage(context, 'Elige al menos un perfil.');
      return;
    }
    setState(() => _saving = true);
    try {
      await AppScope.read(context).createProfile(
        name: _name.text.trim(),
        asClient: _client,
        asBusiness: _business,
      );
      // AuthGate cambia de pantalla en cuanto el perfil se guarda.
    } catch (e) {
      if (mounted) {
        showMessage(context,
            'No se pudo guardar tu perfil. Revisa las reglas de Firestore. ($e)');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _option({
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return AppCard(
      onTap: onTap,
      borderColor: selected ? AppColors.teal : Colors.transparent,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: selected ? AppColors.teal : AppColors.light,
            child: Icon(icon, color: selected ? Colors.white : AppColors.muted),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
          Icon(
            selected ? Icons.check_circle : Icons.circle_outlined,
            color: selected ? AppColors.action : AppColors.gray,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          children: [
            const Text(
              'Crea tu cuenta',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.verified_user_outlined, size: 18, color: AppColors.green),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Vinculada con ${session.email}',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ),
              ],
            ),
            const SectionLabel('Tu nombre'),
            TextField(controller: _name, decoration: fieldDecoration('Nombre completo')),
            const SectionLabel('¿Cómo usarás Bookly?'),
            const Text(
              'Puedes elegir los dos. Después podrás cambiar de interfaz desde tu perfil.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            _option(
              selected: _client,
              icon: Icons.person_outline,
              title: 'Cliente',
              subtitle: 'Busco negocios, veo sus servicios y agendo citas.',
              onTap: () => setState(() => _client = !_client),
            ),
            const SizedBox(height: 10),
            _option(
              selected: _business,
              icon: Icons.storefront_outlined,
              title: 'Negocio',
              subtitle: 'Tengo un negocio: manejo mi agenda, inventario y publicaciones.',
              onTap: () => setState(() => _business = !_business),
            ),
            const SizedBox(height: 24),
            PrimaryButton(label: 'Continuar', loading: _saving, onPressed: _continue),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => session.signOut(),
              child: const Text('Usar otra cuenta de Google'),
            ),
          ],
        ),
      ),
    );
  }
}
