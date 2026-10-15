import 'package:electoral_core/electoral_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kite_ui/kite_ui.dart';

import 'dashboard_providers.dart';

/// Panel principal.
///
/// Muestra el estado de la gestión electoral. No revela votos ni resultados
/// mientras la elección esté abierta: aquí solo hay contadores estructurales,
/// leídos del backend según lo que RLS permite al rol de la sesión.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = KiteText.of(context);
    final counts = ref.watch(dashboardCountsProvider);
    return ListView(
      padding: const EdgeInsets.all(KiteSpace.xl),
      children: [
        Row(
          children: [
            Expanded(child: Text('Panel principal', style: t.h3)),
            KiteButton.outline(
              onPressed: () => ref.invalidate(dashboardCountsProvider),
              leading: const Icon(Icons.refresh, size: 16),
              child: const Text('Actualizar'),
            ),
          ],
        ),
        const SizedBox(height: KiteSpace.xs),
        Text(
          'Resumen de la jornada electoral. Los votos y resultados no se '
          'muestran mientras la elección permanezca abierta.',
          style: t.muted,
        ),
        const SizedBox(height: KiteSpace.xl),
        counts.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: KiteSpace.xxl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => KiteAlert(
            title: 'No se pudieron cargar los contadores',
            description: error.toString(),
            tone: KiteTone.danger,
          ),
          data: (c) => KiteStatGrid(
            children: [
              KiteStat(label: 'Elecciones', value: '${c.elections}'),
              KiteStat(label: 'Cursos', value: '${c.courses}'),
              KiteStat(
                label: 'Estudiantes habilitados',
                value: '${c.enabledStudents}',
              ),
              KiteStat(label: 'Listas registradas', value: '${c.candidateLists}'),
              KiteStat(
                label: 'Dispositivos autorizados',
                value: '${c.authorizedDevices}',
              ),
              KiteStat(
                label: 'Dispositivos pendientes',
                value: '${c.pendingDevices}',
                delta: c.pendingDevices > 0 ? 'sin autorizar' : null,
                deltaTone: KiteTone.warning,
              ),
            ],
          ),
        ),
        const SizedBox(height: KiteSpace.xl),
        KiteCard(
          title: 'Estado del sistema',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Conexión al backend: activa (Supabase).', style: t.small),
              const SizedBox(height: KiteSpace.xs),
              Text(
                'Zona horaria institucional: $kDefaultTimeZone',
                style: t.small,
              ),
              const SizedBox(height: KiteSpace.xs),
              Text(
                'Estados de elección soportados: '
                '${ElectionStatus.values.map((e) => e.name).join(' · ')}',
                style: t.small,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
