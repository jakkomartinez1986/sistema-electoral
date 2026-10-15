import 'package:flutter/material.dart';

/// Módulos de la barra de navegación superior de la administración.
///
/// La especificación pide una barra superior como navegación principal, no una
/// barra lateral permanente. Los módulos se organizan aquí en un solo lugar.
@immutable
class AdminNavItem {
  const AdminNavItem(this.label, this.path, this.icon);

  final String label;
  final String path;
  final IconData icon;
}

const List<AdminNavItem> kAdminNav = <AdminNavItem>[
  AdminNavItem('Panel', '/', Icons.dashboard_outlined),
  AdminNavItem('Institución', '/institucion', Icons.account_balance_outlined),
  AdminNavItem('Cursos y mesas', '/cursos', Icons.groups_outlined),
  AdminNavItem('Padrón', '/padron', Icons.badge_outlined),
  AdminNavItem('Listas', '/listas', Icons.how_to_vote_outlined),
  AdminNavItem('Elecciones', '/elecciones', Icons.event_available_outlined),
  AdminNavItem('Dispositivos', '/dispositivos', Icons.tablet_mac_outlined),
  AdminNavItem('Sincronización', '/sincronizacion', Icons.sync_outlined),
  AdminNavItem('Resultados', '/resultados', Icons.bar_chart_outlined),
  AdminNavItem('Archivo', '/archivo', Icons.archive_outlined),
];
