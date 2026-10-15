import 'package:flutter/material.dart';
import 'package:kite_ui/shadcn.dart';

import 'core/theme/electoral_theme.dart';
import 'features/setup/setup_screen.dart';

/// Raíz de la aplicación de votación estudiantil (Android y Windows).
class VotingApp extends StatelessWidget {
  const VotingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadApp(
      title: 'Votación Estudiantil',
      theme: buildElectoralTheme(Brightness.light),
      darkTheme: buildElectoralTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const SetupScreen(),
    );
  }
}
