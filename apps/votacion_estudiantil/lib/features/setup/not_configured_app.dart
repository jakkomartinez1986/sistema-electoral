import 'package:flutter/material.dart';
import 'package:kite_ui/kite_ui.dart';
import 'package:kite_ui/shadcn.dart';

import '../../core/theme/electoral_theme.dart';

/// Pantalla mostrada cuando la app arranca sin la configuración de Supabase.
class NotConfiguredApp extends StatelessWidget {
  const NotConfiguredApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadApp(
      title: 'Votación Estudiantil',
      theme: buildElectoralTheme(Brightness.light),
      darkTheme: buildElectoralTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: Builder(
        builder: (context) {
          final t = KiteText.of(context);
          final c = KiteColors.of(context);
          return Scaffold(
            backgroundColor: c.background,
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(KiteSpace.xl),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: KiteCard(
                      title: 'Falta configurar el backend',
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const KiteAlert(
                            title: 'Sin variables de Supabase',
                            description:
                                'La aplicación no puede conectarse porque no '
                                'recibió SUPABASE_URL ni SUPABASE_PUBLISHABLE_KEY.',
                            tone: KiteTone.warning,
                          ),
                          const SizedBox(height: KiteSpace.lg),
                          Text(
                            'Ejecuta la app inyectando las variables con '
                            '--dart-define (ver docs/instalacion.md):',
                            style: t.small,
                          ),
                          const SizedBox(height: KiteSpace.sm),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(KiteSpace.md),
                            decoration: BoxDecoration(
                              color: c.muted,
                              borderRadius: KiteRadius.allMd,
                            ),
                            child: Text(
                              'flutter run -d windows '
                              '--dart-define=SUPABASE_URL=... '
                              '--dart-define=SUPABASE_PUBLISHABLE_KEY=...',
                              style: t.muted.copyWith(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
