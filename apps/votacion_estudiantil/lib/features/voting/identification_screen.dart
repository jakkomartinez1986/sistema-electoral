import 'package:electoral_core/electoral_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../core/offline/app_database.dart';
import '../../core/providers.dart';
import '../kiosk/kiosk.dart';
import 'ballot_screen.dart';
import 'voting_providers.dart';

enum _IdMode { cedula, code }

enum _Field { none, cedula, code, pin }

/// Identificación del votante contra el padrón local, sin conexión.
///
/// Se admite **cédula ecuatoriana** o **código estudiantil con PIN** (según lo
/// habilitado por la institución). La comparación usa verificadores opacos; la
/// identidad no se guarda en claro. Ver `docs/manual_votacion.md` §3.
class IdentificationScreen extends ConsumerStatefulWidget {
  const IdentificationScreen({super.key});

  static const String routeName = '/identificacion';

  @override
  ConsumerState<IdentificationScreen> createState() =>
      _IdentificationScreenState();
}

class _IdentificationScreenState extends ConsumerState<IdentificationScreen> {
  final _cedula = TextEditingController();
  final _code = TextEditingController();
  final _pin = TextEditingController();

  _IdMode _mode = _IdMode.cedula;
  _Field _errorField = _Field.none;
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _cedula.dispose();
    _code.dispose();
    _pin.dispose();
    super.dispose();
  }

  void _setMode(_IdMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _error = null;
      _errorField = _Field.none;
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
      _errorField = _Field.none;
    });

    try {
      final repository = ref.read(padronRepositoryProvider);
      final identification = _mode == _IdMode.cedula
          ? await repository.identifyByCedula(_cedula.text)
          : await repository.identifyByCode(code: _code.text, pin: _pin.text);
      if (!mounted) return;

      final status = identification.result.status;
      switch (status) {
        case VoterMatchStatus.found:
          if (identification.hasVoted) {
            setState(() {
              _error = 'Este estudiante ya registró su voto en este equipo.';
              _errorField = _Field.none;
            });
          } else {
            ref
                .read(votingSessionProvider.notifier)
                .identify(identification.voterRef!);
            await _openBallot();
          }
        case VoterMatchStatus.notFound:
          setState(() {
            _error =
                'El votante no consta en el padrón de este equipo. '
                'Verifica la credencial o consulta con el personal.';
            _errorField = _Field.none;
          });
        case VoterMatchStatus.badPin:
          setState(() {
            _error = 'El PIN no coincide.';
            _errorField = _Field.pin;
          });
        case VoterMatchStatus.invalidCedula:
          setState(() {
            _error = 'La cédula no es válida (revisa los dígitos).';
            _errorField = _Field.cedula;
          });
        case VoterMatchStatus.invalidCode:
          setState(() {
            _error = 'Ingresa el código estudiantil.';
            _errorField = _Field.code;
          });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openBallot() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const BallotScreen(),
        settings: const RouteSettings(name: BallotScreen.routeName),
      ),
    );
    if (mounted) _reset();
  }

  void _reset() {
    ref.read(votingSessionProvider.notifier).clear();
    _cedula.clear();
    _code.clear();
    _pin.clear();
    setState(() {
      _error = null;
      _errorField = _Field.none;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = KiteColors.of(context);
    final config = ref.watch(localConfigProvider).value;
    final canSubmit = !_submitting;

    return KioskGuard(
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          backgroundColor: c.background,
          foregroundColor: c.foreground,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: const KioskExitZone(child: Text('Identificar votante')),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(KiteSpace.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (config != null)
                      KioskExitZone(child: _Context(config: config)),
                    const SizedBox(height: KiteSpace.lg),
                    _ModeSelector(mode: _mode, onChanged: _setMode),
                    const SizedBox(height: KiteSpace.lg),
                    KiteCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_mode == _IdMode.cedula)
                            KiteField(
                              label: 'Cédula ecuatoriana',
                              hint: '10 dígitos.',
                              error: _errorField == _Field.cedula
                                  ? _error
                                  : null,
                              child: KiteInput(
                                controller: _cedula,
                                placeholder: '1710034065',
                                keyboardType: TextInputType.number,
                                onChanged: (_) =>
                                    _clearFieldError(_Field.cedula),
                                onSubmitted: (_) => _submit(),
                              ),
                            )
                          else ...[
                            KiteField(
                              label: 'Código estudiantil',
                              hint: 'El código interno del carnet.',
                              error: _errorField == _Field.code ? _error : null,
                              child: KiteInput(
                                controller: _code,
                                placeholder: 'DEMO-001',
                                onChanged: (_) => _clearFieldError(_Field.code),
                              ),
                            ),
                            KiteField(
                              label: 'PIN',
                              hint: 'El PIN asignado al estudiante.',
                              error: _errorField == _Field.pin ? _error : null,
                              child: KiteInput(
                                controller: _pin,
                                placeholder: '••••',
                                obscure: true,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => _clearFieldError(_Field.pin),
                                onSubmitted: (_) => _submit(),
                              ),
                            ),
                          ],
                          if (_error != null && _errorField == _Field.none) ...[
                            KiteAlert(
                              title: 'No se pudo identificar',
                              description: _error,
                              tone: KiteTone.warning,
                            ),
                            const SizedBox(height: KiteSpace.lg),
                          ],
                          KiteButton(
                            expands: true,
                            enabled: canSubmit,
                            onPressed: _submit,
                            leading: const Icon(Icons.badge_outlined),
                            child: Text(
                              _submitting ? 'Verificando…' : 'Continuar',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: KiteSpace.lg),
                    Text(
                      'La identidad se comprueba contra el padrón de este equipo. '
                      'Si hay dudas, consulta con el personal electoral.',
                      textAlign: TextAlign.center,
                      style: KiteText.of(context).muted,
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

  void _clearFieldError(_Field field) {
    if (_errorField == field) {
      setState(() {
        _errorField = _Field.none;
        _error = null;
      });
    }
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.mode, required this.onChanged});

  final _IdMode mode;
  final ValueChanged<_IdMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: mode == _IdMode.cedula
              ? KiteButton(
                  expands: true,
                  onPressed: () => onChanged(_IdMode.cedula),
                  leading: const Icon(Icons.credit_card),
                  child: const Text('Cédula'),
                )
              : KiteButton.outline(
                  expands: true,
                  onPressed: () => onChanged(_IdMode.cedula),
                  leading: const Icon(Icons.credit_card),
                  child: const Text('Cédula'),
                ),
        ),
        const SizedBox(width: KiteSpace.md),
        Expanded(
          child: mode == _IdMode.code
              ? KiteButton(
                  expands: true,
                  onPressed: () => onChanged(_IdMode.code),
                  leading: const Icon(Icons.pin_outlined),
                  child: const Text('Código y PIN'),
                )
              : KiteButton.outline(
                  expands: true,
                  onPressed: () => onChanged(_IdMode.code),
                  leading: const Icon(Icons.pin_outlined),
                  child: const Text('Código y PIN'),
                ),
        ),
      ],
    );
  }
}

class _Context extends StatelessWidget {
  const _Context({required this.config});

  final LocalConfigData config;

  @override
  Widget build(BuildContext context) {
    final t = KiteText.of(context);
    return KiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(config.institutionName, style: t.muted),
          const SizedBox(height: 2),
          Text(config.electionName, style: t.h3),
          if (config.votingTableName != null ||
              config.votingTableCode != null) ...[
            const SizedBox(height: KiteSpace.sm),
            KiteBadge(
              'Mesa ${config.votingTableName ?? config.votingTableCode}',
              tone: KiteTone.info,
            ),
          ],
        ],
      ),
    );
  }
}
