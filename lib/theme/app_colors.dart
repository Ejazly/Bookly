import 'package:flutter/material.dart';

/// Paleta de colores de Bookly.
///
///   #1E5E6B  turquesa profundo  → color principal
///   #28588B  azul               → botones de acción y enlaces
///   #64ABB0  turquesa medio     → acentos y degradados
///   #ADDCEE  azul cielo         → selección, chips
///   #DDF5FB  azul bruma         → fondos suaves
class AppColors {
  static const Color teal = Color(0xFF1E5E6B); // principal
  static const Color deep = Color(0xFF143F48); // fondos oscuros
  static const Color blue = Color(0xFF28588B); // botones y enlaces
  static const Color aqua = Color(0xFF64ABB0); // acentos
  static const Color sky = Color(0xFFADDCEE); // selección
  static const Color mist = Color(0xFFDDF5FB); // fondos suaves

  static const Color action = blue; // botones principales
  static const Color light = Color(0xFFF2FAFC); // fondo general
  static const Color gray = Color(0xFFC6DCE3); // bordes
  static const Color line = Color(0xFFDCEBEF); // divisores

  static const Color ink = Color(0xFF15333B); // texto principal
  static const Color muted = Color(0xFF5E7A83); // texto secundario

  // Colores de estado (se mantienen para que se entiendan solos)
  static const Color green = Color(0xFF2E9673); // éxito, pagado
  static const Color greenSoft = Color(0xFFE2F4EC);
  static const Color amber = Color(0xFFE9A23B); // estrellas y avisos
  static const Color amberSoft = Color(0xFFFDF1DC);
  static const Color red = Color(0xFFC24D4D);
  static const Color redSoft = Color(0xFFFBE7E7);
}
