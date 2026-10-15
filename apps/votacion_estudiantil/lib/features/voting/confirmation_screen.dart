import 'dart:async';

import 'package:electoral_core/electoral_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../core/offline/app_database.dart';
import '../../core/voting/voting_repository.dart';
import '../kiosk/kiosk.dart';
import 'receipt_screen.dart';
import 'voting_providers.dart';

/// Confirmación explícita antes de registrar el voto.
///
/// Hasta que el votante confirma aquí, no se escribe nada. Tras confirmar, el
/// voto no puede cambiarse (salvo un procedimiento institucional documentado).
class ConfirmationScreen extends ConsumerStatefulWidget {
  const ConfirmationScreen({super.key, required this.option});

  static const String routeName = '/confirmacion';

  final BallotOption option;

  @override
  ConsumerState<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends ConsumerState<ConfirmationScreen> {
  bool _submitting = false;
  String? _error;

  Future<void> _confirm() async {
    final session = ref.read(votingSessionProvider);
    if (session == null) {
      setState(
        () => _error =
            'La sesión del votante se perdió. Reinicia el '
            'flujo de identificación.',
      );
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final receipt = await ref
          .read(votingRepositoryProvider)
          .recordVote(voterRef: session.voterRef, option: widget.option);
      if (!mounted) return;
      // Intenta enviar cuanto antes sin bloquear el flujo: si no hay red, el
      // voto queda en la cola y se reintenta (offline-first).
      unawaited(
        ref.read(syncControllerProvider.notifier).syncNow(force: false),
      );
      ref.read(votingSessionProvider.notifier).clear();
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ReceiptScreen(receipt: receipt),
          settings: const RouteSettings(name: ReceiptScreen.routeName),
        ),
      );
    } on VotingException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'No se pudo registrar el voto: $error');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = KiteColors.of(context);
    final t = KiteText.of(context);
    final option = widget.option;
    final catalog = ref.watch(ballotCatalogProvider).value;
    LocalList? list;
    final listId = option.candidateListId;
    if (listId != null && catalog != null) {
      for (final candidate in catalog.lists) {
        if (candidate.id == listId) {
          list = candidate;
          break;
        }
      }
    }

    return KioskGuard(
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          backgroundColor: c.background,
          foregroundColor: c.foreground,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: const KioskExitZone(child: Text('Confirmar voto')),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(KiteSpace.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: KiteCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Tu elección', style: t.small),
                      const SizedBox(height: KiteSpace.sm),
                      Row(
                        children: [
                          if (list != null) ...[
                            Container(
                              width: 48,
                              height: 48,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: c.muted,
                                borderRadius: KiteRadius.allMd,
                              ),
                              child: Text('${list.number}', style: t.h3),
                            ),
                            const SizedBox(width: KiteSpace.md),
                          ] else
                            Icon(
                              option.type == BallotOptionType.blank
                                  ? Icons.check_box_outline_blank
                                  : Icons.block_outlined,
                              size: 40,
                            ),
                          const SizedBox(width: KiteSpace.md),
                          Expanded(
                            child: Text(
                              list?.name ?? option.type.label,
                              style: t.h3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: KiteSpace.lg),
                      KiteAlert(
                        title: 'Revisa antes de confirmar',
                        description:
                            'Después de confirmar, el voto queda '
                            'registrado y no puede cambiarse.',
                        tone: KiteTone.info,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: KiteSpace.lg),
                        KiteAlert(
                          title: 'No se pudo registrar',
                          description: _error,
                          tone: KiteTone.danger,
                        ),
                      ],
                      const SizedBox(height: KiteSpace.lg),
                      KiteButton(
                        expands: true,
                        enabled: !_submitting,
                        onPressed: _confirm,
                        leading: const Icon(Icons.how_to_vote),
                        child: Text(
                          _submitting ? 'Registrando…' : 'Confirmar voto',
                        ),
                      ),
                      const SizedBox(height: KiteSpace.sm),
                      KiteButton.outline(
                        expands: true,
                        enabled: !_submitting,
                        onPressed: () => Navigator.of(context).pop(),
                        leading: const Icon(Icons.arrow_back),
                        child: const Text('Volver a la papeleta'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
