import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kite_ui/kite_ui.dart';

/// Modo kiosco: mantiene el equipo "atado" al flujo de votación.
///
/// Mientras está activo se ocultan las barras del sistema (solo Android) y se
/// bloquea la navegación hacia atrás, de modo que el votante no pueda salir del
/// flujo por accidente. El personal sale manteniendo pulsado el encabezado y
/// confirmando la salida. Ver `docs/manual_votacion.md`.
///
/// Este bloqueo es **dentro de la app**: no impide que el votante use los
/// botones físicos de inicio/ajustes del sistema operativo. El bloqueo a nivel
/// de dispositivo (pantalla fijada / Assigned Access) es una tarea de
/// aprovisionamiento del equipo, no de la aplicación.
class KioskController extends Notifier<bool> {
  @override
  bool build() => false;

  /// Activa el modo kiosco. Idempotente.
  Future<void> enable() async {
    if (state) return;
    state = true;
    _applyImmersive(true);
  }

  /// Desactiva el modo kiosco y restaura las barras del sistema.
  Future<void> disable() async {
    if (!state) return;
    state = false;
    _applyImmersive(false);
  }

  void _applyImmersive(bool immersive) {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      ),
    );
  }
}

final kioskModeProvider = NotifierProvider<KioskController, bool>(
  KioskController.new,
);

/// Bloquea el botón/gesto de "atrás" mientras el votante está en el flujo.
///
/// Solo intercepta la navegación iniciada por la persona; los `pop`/`popUntil`
/// programáticos (por ejemplo, volver a la papeleta o cerrar el flujo) siguen
/// funcionando.
class KioskGuard extends StatelessWidget {
  const KioskGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(canPop: false, child: child);
  }
}

/// Zona de salida del personal: mantener pulsado el encabezado abre la
/// confirmación para desbloquear el equipo.
class KioskExitZone extends ConsumerWidget {
  const KioskExitZone({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => requestKioskExit(context, ref),
      child: child,
    );
  }
}

/// Confirma con el personal y, si acepta, desbloquea el equipo y vuelve a la
/// pantalla de configuración (raíz de la navegación).
Future<void> requestKioskExit(BuildContext context, WidgetRef ref) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final confirmed = await kiteConfirm(
    context,
    title: 'Salir del modo kiosco',
    message:
        'El equipo volverá a la pantalla de configuración y la votación '
        'quedará en pausa. Confirma solo si eres el personal electoral.',
    confirmLabel: 'Salir',
    cancelLabel: 'Cancelar',
  );
  if (!confirmed) return;

  await ref.read(kioskModeProvider.notifier).disable();
  navigator.popUntil((route) => route.isFirst);
}
