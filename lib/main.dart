import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'models/models.dart';
import 'screens/business_panel_screen.dart';
import 'screens/business_setup_screen.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'state/app_state.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

/// Punto de entrada de la aplicación.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Si todavía no hay datos de Firebase para esta plataforma, se muestra una
  // pantalla con instrucciones en lugar de que la app truene.
  // (Funciona igual si firebase_options.dart lo generó `flutterfire configure`.)
  final FirebaseOptions options;
  try {
    options = DefaultFirebaseOptions.currentPlatform;
  } catch (_) {
    runApp(const _MissingConfigApp());
    return;
  }
  if (options.apiKey.startsWith('PEGA_AQUI')) {
    runApp(const _MissingConfigApp());
    return;
  }

  await Firebase.initializeApp(options: options);
  runApp(BooklyApp(session: AppSession()));
}

class BooklyApp extends StatelessWidget {
  const BooklyApp({super.key, required this.session});

  final AppSession session;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      session: session,
      child: MaterialApp(
        title: 'Bookly',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const AuthGate(),
      ),
    );
  }
}

/// Decide qué pantalla mostrar según la sesión:
///   sin sesión            → Inicio de sesión con Google
///   cuenta nueva          → "¿Cómo usarás Bookly?" (elegir perfil)
///   interfaz de negocio   → configurar negocio o panel del negocio
///   interfaz de cliente   → inicio del cliente
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);

    if (!s.authLoaded) return const _Splash();
    if (s.user == null) return const LoginScreen();
    if (!s.profileLoaded) return const _Splash();

    final profile = s.profile;
    if (profile == null) return const RoleSelectionScreen();

    if (profile.mode == AppMode.business) {
      if (!s.businessLoaded) return const _Splash();
      if (s.myBusiness == null) return const BusinessSetupScreen();
      return const BusinessShell();
    }
    return const HomeShell();
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.teal,
      body: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}

class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.settings_suggest_outlined, size: 56, color: AppColors.teal),
                SizedBox(height: 14),
                Text(
                  'Falta conectar Firebase',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  'Ejecuta `flutterfire configure` (o pega los datos de tu proyecto '
                  'en lib/firebase_options.dart) para esta plataforma. Los pasos '
                  'están en la guía FIREBASE_Y_CORREO.md.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
