import 'package:flutter/widgets.dart';
import 'package:kite_ui/shadcn.dart';

/// Tema institucional de la aplicación de votación.
///
/// Mismo esquema azul que la administración para mantener identidad coherente.
/// La papeleta en sí se renderiza de forma neutra en etapas posteriores, sin
/// favorecer visualmente a ninguna lista.
ShadThemeData buildElectoralTheme(Brightness brightness) => ShadThemeData(
      brightness: brightness,
      colorScheme: brightness == Brightness.dark
          ? const ShadBlueColorScheme.dark()
          : const ShadBlueColorScheme.light(),
    );
