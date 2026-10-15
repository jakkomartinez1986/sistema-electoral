import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kite_ui/shadcn.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// Raíz de la aplicación de administración electoral (Windows).
class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ShadApp.router(
      title: 'Administración Electoral',
      theme: buildElectoralTheme(Brightness.light),
      darkTheme: buildElectoralTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
