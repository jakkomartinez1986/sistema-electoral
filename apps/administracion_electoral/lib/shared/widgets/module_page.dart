import 'package:flutter/material.dart';
import 'package:kite_ui/kite_ui.dart';

/// Estructura común de las páginas de módulo: título, descripción, acciones y
/// un área de contenido que ocupa el resto del alto disponible.
///
/// El contenido se coloca en un área acotada (`Expanded`), de modo que las
/// tablas `KiteDataTable` puedan ocupar la pantalla y desplazarse internamente.
class ModulePage extends StatelessWidget {
  const ModulePage({
    super.key,
    required this.title,
    required this.child,
    this.description,
    this.actions = const <Widget>[],
  });

  final String title;
  final String? description;
  final List<Widget> actions;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = KiteText.of(context);
    return Padding(
      padding: const EdgeInsets.all(KiteSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.h3),
                    if (description != null) ...[
                      const SizedBox(height: KiteSpace.xs),
                      Text(description!, style: t.muted),
                    ],
                  ],
                ),
              ),
              if (actions.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < actions.length; i++)
                      Padding(
                        padding: EdgeInsets.only(
                          left: i == 0 ? 0 : KiteSpace.sm,
                        ),
                        child: actions[i],
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: KiteSpace.xl),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Fila etiqueta/valor para secciones de detalle.
class DetailRow extends StatelessWidget {
  const DetailRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = KiteText.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: KiteSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 200,
            child: Text(label, style: t.small.copyWith(fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value, style: t.p)),
        ],
      ),
    );
  }
}
