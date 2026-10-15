import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/router/nav_items.dart';

/// Contenedor de la aplicación de administración: barra superior fija y área de
/// contenido adaptable. Sin barra lateral permanente, según el diseño pedido.
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = KiteColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopNav(location: location),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _TopNav extends ConsumerWidget {
  const _TopNav({required this.location});
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = KiteColors.of(context);
    final t = KiteText.of(context);
    final profile = ref.watch(authControllerProvider).value;
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: c.card,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: KiteSpace.xl),
      child: Row(
        children: [
          Icon(Icons.how_to_vote_outlined, color: c.primary, size: 22),
          const SizedBox(width: KiteSpace.sm),
          Text('Elecciones', style: t.h4),
          const SizedBox(width: KiteSpace.xxl),
          Expanded(child: _NavRow(location: location)),
          if (profile != null) ...[
            const SizedBox(width: KiteSpace.lg),
            Text(
              profile.fullName,
              style: t.small.copyWith(fontWeight: FontWeight.w500),
            ),
            if (profile.roles.isNotEmpty) ...[
              const SizedBox(width: KiteSpace.sm),
              Text(profile.roles.map((r) => r.name).join(' · '), style: t.muted),
            ],
            const SizedBox(width: KiteSpace.md),
            KiteButton.ghost(
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).signOut(),
              leading: const Icon(Icons.logout, size: 16),
              child: const Text('Salir'),
            ),
          ],
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.location});
  final String location;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in kAdminNav)
            _NavLink(item: item, active: location == item.path),
        ],
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({required this.item, required this.active});
  final AdminNavItem item;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = KiteColors.of(context);
    final t = KiteText.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: active ? c.accent : Colors.transparent,
        borderRadius: KiteRadius.allSm,
        child: InkWell(
          borderRadius: KiteRadius.allSm,
          onTap: () => context.go(item.path),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KiteSpace.md,
              vertical: 8,
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 16,
                  color: active ? c.foreground : c.mutedForeground,
                ),
                const SizedBox(width: KiteSpace.sm),
                Text(
                  item.label,
                  style: t.small.copyWith(
                    color: active ? c.foreground : c.mutedForeground,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
