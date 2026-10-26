import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import 'appointments_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'videos_screen.dart';

/// Contenedor con la barra de navegación inferior del cliente:
/// Inicio, Videos, Mis citas y Perfil.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      // IndexedStack mantiene vivas las 4 pestañas y solo muestra una.
      body: IndexedStack(
        index: state.tab,
        children: const [
          HomeScreen(),
          VideosScreen(),
          AppointmentsScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: state.tab,
        onDestinationSelected: (i) => state.tab = i,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0x331C6470),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppColors.teal),
            label: 'Inicio',
          ),
          const NavigationDestination(
            icon: Icon(Icons.play_circle_outline),
            selectedIcon: Icon(Icons.play_circle, color: AppColors.teal),
            label: 'Videos',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: state.upcoming.isNotEmpty,
              label: Text('${state.upcoming.length}'),
              child: const Icon(Icons.event_note_outlined),
            ),
            selectedIcon: const Icon(Icons.event_note, color: AppColors.teal),
            label: 'Mis citas',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppColors.teal),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
