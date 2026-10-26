import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import 'business_screen.dart';

/// Pantalla 3.3: Inicio / Explorar negocios.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _query = '';
  BusinessCategory? _category; // null = Todos

  Widget _chip(String label, BusinessCategory? category) {
    final selected = _category == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => setState(() => _category = category),
        selectedColor: AppColors.teal,
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.teal,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide(color: selected ? AppColors.teal : AppColors.gray),
        shape: const StadiumBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final q = _query.trim().toLowerCase();

    // Filtra por categoría y por texto (nombre del negocio o de un servicio).
    final list = state.businesses.where((b) {
      final matchesCategory = _category == null || b.category == _category;
      final matchesText = q.isEmpty ||
          b.name.toLowerCase().contains(q) ||
          b.services.any((s) => s.name.toLowerCase().contains(q));
      return matchesCategory && matchesText;
    }).toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    final promos = state.businesses.where((b) => b.promo != null).toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hola, ${state.userName}',
                        style: const TextStyle(color: AppColors.muted)),
                    const Text(
                      '¿Qué te hacemos hoy?',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filled(
                onPressed: () => showSoon(context),
                style: IconButton.styleFrom(backgroundColor: AppColors.teal),
                icon: const Icon(Icons.notifications_none, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration:
                fieldDecoration('Buscar negocio o servicio', icon: Icons.search),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _chip('Todos', null),
                for (final c in BusinessCategory.values) _chip(c.label, c),
              ],
            ),
          ),
          if (promos.isNotEmpty && q.isEmpty && _category == null) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => openBusiness(context, promos.first),
              child: GradientBox(
                colors: const [AppColors.blue, AppColors.teal],
                radius: 16,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PROMOCIÓN',
                        style: TextStyle(color: Color(0xDDFFFFFF), fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        promos.first.promo!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        promos.first.name,
                        style: const TextStyle(
                            color: Color(0xDDFFFFFF), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Cerca de ti',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () => showSoon(context),
                child: const Text('Ver mapa'),
              ),
            ],
          ),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No encontramos negocios con esa búsqueda.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          for (final b in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: BusinessCard(
                business: b,
                now: state.now,
                onTap: () => openBusiness(context, b),
              ),
            ),
        ],
      ),
    );
  }
}
