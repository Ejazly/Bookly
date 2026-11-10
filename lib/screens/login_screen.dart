import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';

/// Pantalla de inicio de sesión y registro.
///
/// Se puede entrar de dos formas:
///  - Con correo y contraseña (se crea la cuenta aquí mismo).
///  - Con Google, en un toque, si ya tienes tu Gmail abierto.
/// En los dos casos los avisos de las citas llegan a ese correo.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _register = false; // false = Iniciar sesión, true = Crear cuenta
  bool _hidePassword = true;
  bool _loading = false;
  bool _googleLoading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      if (_register) {
        await AuthService.signUpWithEmail(
          name: _name.text,
          email: _email.text,
          password: _password.text,
        );
      } else {
        await AuthService.signInWithEmail(email: _email.text, password: _password.text);
      }
      // AuthGate cambia de pantalla solo al detectar la sesión.
    } catch (e) {
      if (mounted) showMessage(context, AuthService.messageFor(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    setState(() => _googleLoading = true);
    try {
      await AuthService.signInWithGoogle();
    } catch (e) {
      if (mounted) showMessage(context, AuthService.messageFor(e));
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _forgot() async {
    final email = _email.text.trim();
    if (!_validEmail(email)) {
      showMessage(context, 'Escribe tu correo arriba y vuelve a tocar "¿Olvidaste tu contraseña?".');
      return;
    }
    try {
      await AuthService.sendPasswordReset(email);
      if (!mounted) return;
      await showInfoDialog(
        context,
        title: 'Revisa tu correo',
        message: 'Si $email tiene una cuenta en Bookly, te mandamos un enlace para crear '
            'una contraseña nueva. Revisa también la carpeta de spam.',
        icon: Icons.mark_email_read_outlined,
        color: AppColors.teal,
      );
    } catch (e) {
      if (mounted) showMessage(context, AuthService.messageFor(e));
    }
  }

  static bool _validEmail(String v) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[a-zA-Z]{2,}$').hasMatch(v.trim());

  String? _passwordRule(String? v) {
    final t = v ?? '';
    if (t.isEmpty) return 'Escribe una contraseña';
    if (!_register) return null;
    if (t.length < 8) return 'Mínimo 8 caracteres';
    if (!RegExp(r'[A-Za-z]').hasMatch(t) || !RegExp(r'\d').hasMatch(t)) {
      return 'Usa letras y números';
    }
    return null;
  }

  InputDecoration _field(String label, IconData icon, {Widget? suffix}) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.teal),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.light,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.gray),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.gray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.teal, width: 2),
        ),
      );

  Widget _modeSwitch() {
    Widget tab(String label, bool value) {
      final selected = _register == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() {
            _register = value;
            _formKey.currentState?.reset();
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: selected
                  ? const [BoxShadow(color: Color(0x1A143F48), blurRadius: 8, offset: Offset(0, 2))]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: selected ? AppColors.teal : AppColors.muted,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.mist, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [tab('Iniciar sesión', false), tab('Crear cuenta', true)]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final busy = _loading || _googleLoading;
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.teal, AppColors.blue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: EdgeInsets.fromLTRB(24, topPadding + 36, 24, 64),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: Image.asset('assets/logo.png', width: 104, height: 104, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 12),
                  const Text('Bookly',
                      style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Encuentra, compara y reserva tu servicio',
                      style: TextStyle(color: AppColors.mist, fontSize: 13)),
                ],
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: AppCard(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _modeSwitch(),
                              const SizedBox(height: 18),
                              Text(
                                _register ? 'Crea tu cuenta' : 'Qué gusto verte',
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.ink),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _register
                                    ? 'A este correo te avisaremos de tus citas (de preferencia tu Gmail).'
                                    : 'Entra con tu correo y contraseña.',
                                style: const TextStyle(color: AppColors.muted, fontSize: 13),
                              ),
                              const SizedBox(height: 16),
                              if (_register) ...[
                                TextFormField(
                                  controller: _name,
                                  textCapitalization: TextCapitalization.words,
                                  autofillHints: const [AutofillHints.name],
                                  textInputAction: TextInputAction.next,
                                  decoration: _field('Nombre de usuario', Icons.person_outline_rounded),
                                  validator: (v) {
                                    final t = (v ?? '').trim();
                                    if (t.length < 2) return 'Escribe tu nombre';
                                    if (t.length > 60) return 'Máximo 60 caracteres';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                              ],
                              TextFormField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                                textInputAction: TextInputAction.next,
                                decoration: _field('Correo electrónico', Icons.mail_outline_rounded),
                                validator: (v) => _validEmail(v ?? '') ? null : 'Escribe un correo válido',
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _password,
                                obscureText: _hidePassword,
                                autofillHints: [
                                  _register ? AutofillHints.newPassword : AutofillHints.password,
                                ],
                                textInputAction: _register ? TextInputAction.next : TextInputAction.done,
                                onFieldSubmitted: (_) => _register ? null : _submit(),
                                decoration: _field(
                                  'Contraseña',
                                  Icons.lock_outline_rounded,
                                  suffix: IconButton(
                                    tooltip: _hidePassword ? 'Mostrar' : 'Ocultar',
                                    onPressed: () => setState(() => _hidePassword = !_hidePassword),
                                    icon: Icon(_hidePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined),
                                  ),
                                ),
                                validator: _passwordRule,
                              ),
                              if (_register) ...[
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _confirm,
                                  obscureText: _hidePassword,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submit(),
                                  decoration: _field('Confirmar contraseña', Icons.lock_reset_rounded),
                                  validator: (v) =>
                                      v == _password.text ? null : 'Las contraseñas no coinciden',
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Mínimo 8 caracteres, con letras y números.',
                                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                                ),
                              ] else
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: busy ? null : _forgot,
                                    child: const Text('¿Olvidaste tu contraseña?'),
                                  ),
                                ),
                              const SizedBox(height: 12),
                              PrimaryButton(
                                label: _register ? 'Crear cuenta' : 'Iniciar sesión',
                                loading: _loading,
                                onPressed: busy ? null : _submit,
                              ),
                              const SizedBox(height: 18),
                              const Row(
                                children: [
                                  Expanded(child: Divider()),
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 10),
                                    child: Text('o', style: TextStyle(color: AppColors.muted)),
                                  ),
                                  Expanded(child: Divider()),
                                ],
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                height: 50,
                                child: OutlinedButton.icon(
                                  onPressed: busy ? null : _google,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.ink,
                                    side: const BorderSide(color: AppColors.gray),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14)),
                                  ),
                                  icon: _googleLoading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.g_mobiledata, size: 30, color: AppColors.blue),
                                  label: const Text('Continuar con Google'),
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Row(
                                children: [
                                  Icon(Icons.lock_outline, size: 15, color: AppColors.muted),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Tu contraseña se guarda cifrada en Firebase; nadie en Bookly puede verla.',
                                      style: TextStyle(fontSize: 11, color: AppColors.muted),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
