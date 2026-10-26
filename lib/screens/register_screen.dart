import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import 'business_panel_screen.dart';
import 'home_shell.dart';

/// Pantalla 3.2: Registro. La usuaria elige si es Cliente o Negocio.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _isBusiness = false;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _register() {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      showMessage(context, 'Debes aceptar los términos y el aviso de privacidad.');
      return;
    }
    final state = AppScope.read(context);
    state.userName = _name.text.trim().split(' ').first;
    state.tab = 0;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) =>
            _isBusiness ? const BusinessPanelScreen() : const HomeShell(),
      ),
      (route) => false,
    );
  }

  Widget _roleCard({
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: AppCard(
        onTap: onTap,
        borderColor: selected ? AppColors.teal : Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Icon(icon,
                size: 30,
                color: selected ? AppColors.teal : AppColors.muted),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: selected ? AppColors.teal : AppColors.ink,
              ),
            ),
            Text(subtitle,
                style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String? requiredField(String? v) =>
        (v ?? '').trim().isEmpty ? 'Este campo es obligatorio' : null;

    return Scaffold(
      appBar: AppBar(),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            const Text(
              'Crea tu cuenta',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text('¿Cómo usarás Bookly?',
                style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 16),
            Row(
              children: [
                _roleCard(
                  selected: !_isBusiness,
                  icon: Icons.person_outline,
                  title: 'Cliente',
                  subtitle: 'Busco y reservo',
                  onTap: () => setState(() => _isBusiness = false),
                ),
                const SizedBox(width: 10),
                _roleCard(
                  selected: _isBusiness,
                  icon: Icons.storefront_outlined,
                  title: 'Negocio',
                  subtitle: 'Ofrezco servicios',
                  onTap: () => setState(() => _isBusiness = true),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _name,
              decoration: fieldDecoration(
                  _isBusiness ? 'Nombre del negocio' : 'Nombre completo'),
              validator: requiredField,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: fieldDecoration('Correo electrónico'),
              validator: (v) => (v ?? '').contains('@')
                  ? null
                  : 'Escribe un correo válido',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: fieldDecoration('Teléfono (10 dígitos)'),
              validator: (v) =>
                  RegExp(r'^\d{10}$').hasMatch((v ?? '').trim())
                      ? null
                      : 'El teléfono debe tener 10 dígitos',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: fieldDecoration('Contraseña'),
              validator: (v) =>
                  (v ?? '').length < 6 ? 'Mínimo 6 caracteres' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              decoration: fieldDecoration('Confirmar contraseña'),
              validator: (v) =>
                  v != _password.text ? 'Las contraseñas no coinciden' : null,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: _acceptedTerms,
                  activeColor: AppColors.teal,
                  onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                ),
                const Expanded(
                  child: Text(
                    'Acepto términos y aviso de privacidad',
                    style: TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            PrimaryButton(label: 'Registrarme', onPressed: _register),
          ],
        ),
      ),
    );
  }
}
