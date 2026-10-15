import 'package:flutter/material.dart';
import 'package:kite_ui/kite_ui.dart';

/// Pantalla de módulo aún no implementado.
///
/// Es honesta a propósito: indica que el módulo existe en la navegación pero su
/// funcionalidad se implementa en etapas posteriores. Evita rutas muertas.
class ModulePlaceholderScreen extends StatelessWidget {
  const ModulePlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final t = KiteText.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: KiteCard(
          title: title,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Módulo en construcción', style: t.lead),
              const SizedBox(height: KiteSpace.sm),
              Text(
                'Este módulo forma parte del plan (Etapas 2 y 3). Se implementará '
                'de forma incremental, con migraciones y pruebas antes de usarlo '
                'en una jornada electoral real.',
                style: t.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
