import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import 'business_panel_screen.dart';
import 'home_shell.dart';
import 'register_screen.dart';

/// Pantalla 3.1: Inicio de sesión.
/// En esta versión no hay autenticación real: se validan los campos y se entra.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _enterAsClient(String name) {
    final state = AppScope.read(context);
    state.userName = name;
    state.tab = 0;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeShell()),
    );
  }

  void _login() {
    if (!_formKey.currentState!.validate()) return;
    final user = _email.text.trim().split('@').first;
    final name = user.isEmpty
        ? 'Ana'
        : '${user[0].toUpperCase()}${user.substring(1)}';
    _enterAsClient(name);
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Encabezado turquesa con el logo
            Container(
              width: double.infinity,
              color: AppColors.teal,
              padding: EdgeInsets.fromLTRB(24, topPadding + 36, 24, 70),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Bookly',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Encuentra, compara y reserva tu servicio',
                    style: TextStyle(color: Color(0xDDFFFFFF), fontSize: 13),
                  ),
                ],
              ),
            ),
            // Tarjeta del formulario (sube un poco sobre el encabezado)
            Transform.translate(
              offset: const Offset(0, -44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Iniciar sesión',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: fieldDecoration('correo@ejemplo.com',
                              icon: Icons.mail_outline),
                          validator: (v) {
                            final text = (v ?? '').trim();
                            if (!text.contains('@') || !text.contains('.')) {
                              return 'Escribe un correo válido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          obscureText: _hidePassword,
                          decoration: fieldDecoration('Contraseña',
                                  icon: Icons.lock_outline)
                              .copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(_hidePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                              onPressed: () => setState(
                                  () => _hidePassword = !_hidePassword),
                            ),
                          ),
                          validator: (v) => (v ?? '').length < 6
                              ? 'Mínimo 6 caracteres'
                              : null,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => showSoon(context),
                            child: const Text('¿Olvidaste tu contraseña?'),
                          ),
                        ),
                        PrimaryButton(label: 'Entrar', onPressed: _login),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: () => _enterAsClient('Ana'),
                            icon: const Icon(Icons.g_mobiledata, size: 28),
                            label: const Text('Continuar con Google'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.teal,
                              side: const BorderSide(
                                  color: AppColors.teal, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('¿No tienes cuenta?',
                    style: TextStyle(color: AppColors.muted)),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  ),
                  child: const Text('Regístrate'),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                    builder: (_) => const BusinessPanelScreen()),
              ),
              icon: const Icon(Icons.storefront_outlined),
              label: const Text('Entrar como negocio (demo)'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
