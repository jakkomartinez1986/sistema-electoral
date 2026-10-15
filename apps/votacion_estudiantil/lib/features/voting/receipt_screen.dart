import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../core/voting/voting_repository.dart';
import '../kiosk/kiosk.dart';
import 'identification_screen.dart';
import 'voting_providers.dart';

/// Confirmación **neutra** de que el voto se registró localmente.
///
/// No revela la opción elegida ni muestra resultados parciales. El voto queda
/// en la cola local y se sincronizará cuando haya conexión.
class ReceiptScreen extends ConsumerWidget {
  const ReceiptScreen({super.key, required this.receipt});

  static const String routeName = '/recibo';

  final CastReceipt receipt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = KiteColors.of(context);
    final t = KiteText.of(context);
    final pending = ref.watch(outboxPendingProvider).value ?? 0;

    return KioskGuard(
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(KiteSpace.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    KiteCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(
                            Icons.verified_outlined,
                            size: 64,
                            color: c.primary,
                          ),
                          const SizedBox(height: KiteSpace.lg),
                          KioskExitZone(
                            child: Text(
                              'Voto recibido',
                              textAlign: TextAlign.center,
                              style: t.h2,
                            ),
                          ),
                          const SizedBox(height: KiteSpace.sm),
                          Text(
                            'El voto quedó registrado en este equipo. Se enviará '
                            'al servidor cuando haya conexión y no puede '
                            'cambiarse.',
                            textAlign: TextAlign.center,
                            style: t.muted,
                          ),
                          const SizedBox(height: KiteSpace.xl),
                          _Row(
                            label: 'Registrado',
                            value: DateFormat('yyyy-MM-dd HH:mm')
                                .format(receipt.castAt.toLocal()),
                          ),
                          _Row(
                            label: 'Identificador de operación',
                            value: receipt.shortOperationId,
                            monospace: true,
                          ),
                          _Row(
                            label: 'Por sincronizar',
                            value: '$pending operación(es)',
                          ),
                          const SizedBox(height: KiteSpace.lg),
                          KiteButton(
                            expands: true,
                            onPressed: () => _finish(context),
                            leading: const Icon(Icons.done_all),
                            child: const Text('Listo'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: KiteSpace.lg),
                    Text(
                      'Entrega el equipo al siguiente votante.',
                      textAlign: TextAlign.center,
                      style: t.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _finish(BuildContext context) {
    Navigator.of(context).popUntil(
      (route) => route.settings.name == IdentificationScreen.routeName,
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.monospace = false,
  });

  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final t = KiteText.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: t.small)),
          Text(
            value,
            style: monospace ? t.muted.copyWith(fontFamily: 'monospace') : t.p,
          ),
        ],
      ),
    );
  }
}
