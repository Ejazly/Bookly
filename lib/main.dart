import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

/// Punto de entrada de la aplicación.
void main() {
  runApp(BooklyApp(state: AppState()));
}

class BooklyApp extends StatelessWidget {
  const BooklyApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    // AppScope envuelve toda la app para que cualquier pantalla
    // pueda leer las citas y los negocios.
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'Bookly',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const LoginScreen(),
      ),
    );
  }
}
