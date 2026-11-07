import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import 'business/agenda_screen.dart';
import 'business/business_profile_screen.dart';
import 'business/inventory_screen.dart';
import 'business/site_editor_screen.dart';

/// Interfaz de NEGOCIO con sus apartados en la barra inferior:
///   Agenda      clientes con anticipo y personas agregadas por el negocio
///   Mi sitio    decorar la página que ven los clientes
///   Inventario  productos y servicios
///   Cuenta      datos de la cuenta y cambio de interfaz
class BusinessShell extends StatelessWidget {
  const BusinessShell({super.key});

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context);
    final business = session.myBusiness;
    if (business == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: IndexedStack(
        index: session.businessTab,
        children: [
          AgendaScreen(business: business),
          SiteEditorScreen(business: business),
          InventoryScreen(business: business),
          BusinessProfileScreen(business: business),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: session.businessTab,
        onDestinationSelected: (i) => session.businessTab = i,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0x331C6470),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month, color: AppColors.teal),
            label: 'Agenda',
          ),
          NavigationDestination(
            icon: Icon(Icons.web_outlined),
            selectedIcon: Icon(Icons.web, color: AppColors.teal),
            label: 'Mi sitio',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2, color: AppColors.teal),
            label: 'Inventario',
          ),
          NavigationDestination(
            icon: Icon(Icons.manage_accounts_outlined),
            selectedIcon: Icon(Icons.manage_accounts, color: AppColors.teal),
            label: 'Cuenta',
          ),
        ],
      ),
    );
  }
}
