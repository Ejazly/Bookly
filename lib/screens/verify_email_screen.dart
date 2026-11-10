import 'dart:async';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';

/// Se muestra a quien creó su cuenta con correo y contraseña hasta que
/// confirme su correo con el enlace que le mandamos. Así nadie puede usar un
/// correo ajeno y los avisos de las citas llegan a la persona correcta.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  Timer? _poll;
  bool _checking = false;
  int _cooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    // Revisa sola cada 5 segundos si ya se verificó el correo.
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _check(quiet: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _check({bool quiet = false}) async {
    if (_checking || !mounted) return;
    _checking = true;
    if (!quiet) setState(() {});
    try {
      final ok = await AppScope.read(context).refreshVerification();
      if (!ok && !quiet && mounted) {
        showMessage(context, 'Todavía no aparece verificado. Abre el enlace del correo.');
      }
    } catch (_) {
      if (!quiet && mounted) showMessage(context, 'No se pudo revisar. Inténtalo de nuevo.');
    } finally {
      _checking = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _resend() async {
    try {
      await AuthService.resendVerification();
      if (!mounted) return;
      showMessage(context, 'Te mandamos otro correo.');
      setState(() => _cooldown = 60);
      _cooldownTimer?.cancel();
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted || _cooldown <= 1) {
          t.cancel();
          if (mounted) setState(() => _cooldown = 0);
          return;
        }
        setState(() => _cooldown--);
      });
    } catch (e) {
      if (mounted) showMessage(context, AuthService.messageFor(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [AppColors.teal, AppColors.aqua]),
                      ),
                      child: const Icon(Icons.mark_email_unread_outlined, color: Colors.white, size: 46),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Confirma tu correo',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(
                    'Te mandamos un enlace a\n${session.email}\n\nÁbrelo para activar tu cuenta. '
                    'Esta pantalla avanzará sola en cuanto lo confirmes.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '¿No lo ves? Revisa la carpeta de spam o promociones.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Ya lo confirmé',
                    loading: _checking,
                    onPressed: () => _check(),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _cooldown > 0 ? null : _resend,
                    child: Text(_cooldown > 0 ? 'Reenviar en $_cooldown s' : 'Reenviar correo'),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => session.signOut(),
                    child: const Text('Usar otra cuenta'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
