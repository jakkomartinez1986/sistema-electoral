import 'package:flutter/widgets.dart';
import 'package:kite_ui/shadcn.dart';

/// Tema institucional del Sistema Electoral Estudiantil.
///
/// Azul como color principal. El rojo del esquema (`destructive`) queda
/// reservado como acento para acciones sensibles y advertencias. El ajuste fino
/// de la identidad institucional (logotipo, matices exactos) se configura en
/// una etapa posterior sin tocar las pantallas.
ShadThemeData buildElectoralTheme(Brightness brightness) => ShadThemeData(
      brightness: brightness,
      colorScheme: brightness == Brightness.dark
          ? const ShadBlueColorScheme.dark()
          : const ShadBlueColorScheme.light(),
    );
