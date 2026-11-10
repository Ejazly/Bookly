import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import 'appointments_screen.dart';
import 'feed_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

/// Interfaz de CLIENTE con su barra inferior:
/// Inicio, Novedades, Mis citas y Perfil.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context);
    return Scaffold(
      // IndexedStack mantiene vivas las 4 pestañas y solo muestra una.
      body: IndexedStack(
        index: session.clientTab,
        children: const [
          HomeScreen(),
          FeedScreen(),
          AppointmentsScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: session.clientTab,
        onDestinationSelected: (i) => session.clientTab = i,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.sky,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppColors.teal),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.dynamic_feed_outlined),
            selectedIcon: Icon(Icons.dynamic_feed, color: AppColors.teal),
            label: 'Novedades',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note, color: AppColors.teal),
            label: 'Mis citas',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppColors.teal),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
