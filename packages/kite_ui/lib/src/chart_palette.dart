import 'package:flutter/widgets.dart';

/// Categorical palette for charts.
///
/// Charts need more colours than the theme exposes (which is deliberately a
/// small, semantic set). This stays a fixed, ordered palette so the same list
/// keeps the same colour across the donut and the bar chart, and it reads in
/// both light and dark: the hues are mid-tone, so they sit between the two
/// backgrounds.
abstract final class KiteChartPalette {
  static const List<Color> colors = <Color>[
    Color(0xFF2563EB), // azul
    Color(0xFF0C6B62), // verde azulado
    Color(0xFFB03D0B), // naranja quemado
    Color(0xFF7C3AED), // violeta
    Color(0xFF8A5A0B), // ámbar
    Color(0xFFBE185D), // magenta
    Color(0xFF0E7490), // cian
    Color(0xFF4D7C0F), // oliva
  ];

  /// Elige un color por índice, ciclando si hay más series que colores.
  static Color at(int index) => colors[index % colors.length];

  /// Color para blancos y nulos: gris claro/oscuro, fuera de la serie categórica.
  static const Color blank = Color(0xFF94A3B8);
  static const Color nullVote = Color(0xFF64748B);
}
