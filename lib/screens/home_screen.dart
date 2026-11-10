import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/database.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../ads/ads.dart';
import '../widgets/common.dart';
import '../widgets/nearby_section.dart';
import 'business_screen.dart';

/// Inicio del cliente: negocios cerca de ti (con mapa), buscar y explorar.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Stream<List<Business>> _stream = Database.instance.businessesStream();
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
    final session = AppScope.of(context);
    final q = _query.trim().toLowerCase();
    final now = DateTime.now();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        children: [
          Text('Hola, ${session.firstName}',
              style: const TextStyle(color: AppColors.muted)),
          const Text(
            '¿Qué te hacemos hoy?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: fieldDecoration('Buscar negocio o dirección', icon: Icons.search),
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
          const SizedBox(height: 16),
          StreamBuilder<List<Business>>(
            stream: _stream,
            builder: (context, snapshot) {
              final status = streamStatus(snapshot);
              if (status != null) return status;
              final byCategory = snapshot.data!
                  .where((b) => _category == null || b.category == _category)
                  .toList();
              final list = byCategory.where((b) {
                return q.isEmpty ||
                    b.name.toLowerCase().contains(q) ||
                    b.address.toLowerCase().contains(q);
              }).toList();

              final Widget results;
              if (list.isEmpty) {
                results = const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No encontramos negocios con esa búsqueda.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                );
              } else {
                results = Column(
                  children: [
                    for (final b in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: BusinessCard(
                          business: b,
                          now: now,
                          onTap: () => openBusiness(context, b),
                        ),
                      ),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Mientras busca algo, se oculta el mapa para enfocarse en los resultados.
                  if (q.isEmpty) ...[
                    NearbySection(
                      businesses: byCategory,
                      onOpen: (b) => openBusiness(context, b),
                    ),
                    const SizedBox(height: 18),
                    const AdBanner(),
                    const SizedBox(height: 18),
                  ],
                  Text(
                    q.isEmpty ? 'Todos los negocios' : 'Resultados',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  results,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
