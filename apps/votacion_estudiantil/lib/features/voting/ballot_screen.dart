import 'package:electoral_core/electoral_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../core/offline/app_database.dart';
import '../kiosk/kiosk.dart';
import 'ballot_catalog.dart';
import 'confirmation_screen.dart';
import 'voting_providers.dart';

/// Papeleta neutral: cada lista con su número, nombre e integrantes, más las
/// opciones de voto en blanco y nulo. Ninguna opción se resalta por color de
/// marca; solo se marca la selección del votante.
class BallotScreen extends ConsumerStatefulWidget {
  const BallotScreen({super.key});

  static const String routeName = '/papeleta';

  @override
  ConsumerState<BallotScreen> createState() => _BallotScreenState();
}

class _BallotScreenState extends ConsumerState<BallotScreen> {
  BallotOption? _selected;

  void _select(BallotOption option) => setState(() => _selected = option);

  Future<void> _continue() async {
    final option = _selected;
    if (option == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConfirmationScreen(option: option),
        settings: const RouteSettings(name: ConfirmationScreen.routeName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = KiteColors.of(context);
    final catalog = ref.watch(ballotCatalogProvider);

    return KioskGuard(
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          backgroundColor: c.background,
          foregroundColor: c.foreground,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: const KioskExitZone(child: Text('Papeleta')),
        ),
        body: SafeArea(
          child: catalog.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(KiteSpace.xl),
                child: KiteAlert(
                  title: 'No se pudo cargar la papeleta',
                  description: '$error',
                  tone: KiteTone.danger,
                ),
              ),
            ),
            data: (data) => _BallotBody(
              catalog: data,
              selected: _selected,
              onSelect: _select,
            ),
          ),
        ),
        bottomNavigationBar: catalog.maybeWhen(
          data: (data) => data.isEmpty
              ? null
              : _BottomBar(enabled: _selected != null, onContinue: _continue),
          orElse: () => null,
        ),
      ),
    );
  }
}

class _BallotBody extends StatelessWidget {
  const _BallotBody({
    required this.catalog,
    required this.selected,
    required this.onSelect,
  });

  final BallotCatalog catalog;
  final BallotOption? selected;
  final ValueChanged<BallotOption> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = KiteText.of(context);
    if (catalog.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(KiteSpace.xl),
          child: KiteAlert(
            title: 'No hay listas habilitadas',
            description: 'Consulta con el personal electoral antes de votar.',
            tone: KiteTone.warning,
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(KiteSpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Elige una opción', style: t.h2),
              const SizedBox(height: KiteSpace.xs),
              Text(
                'Marca una lista, el voto en blanco o el voto nulo. '
                'Después podrás confirmar antes de enviar.',
                style: t.muted,
              ),
              const SizedBox(height: KiteSpace.xl),
              for (final list in catalog.lists) ...[
                _ListCard(
                  list: list,
                  members: catalog.candidatesOf(list.id),
                  selected: selected?.candidateListId == list.id,
                  onTap: () => onSelect(BallotOption.list(list.id)),
                ),
                const SizedBox(height: KiteSpace.md),
              ],
              const SizedBox(height: KiteSpace.sm),
              Row(
                children: [
                  Expanded(
                    child: _SimpleCard(
                      label: 'Voto en blanco',
                      icon: Icons.check_box_outline_blank,
                      selected: selected?.type == BallotOptionType.blank,
                      onTap: () => onSelect(const BallotOption.blank()),
                    ),
                  ),
                  const SizedBox(width: KiteSpace.md),
                  Expanded(
                    child: _SimpleCard(
                      label: 'Voto nulo',
                      icon: Icons.block_outlined,
                      selected: selected?.type == BallotOptionType.nullVote,
                      onTap: () => onSelect(const BallotOption.nullVote()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: KiteSpace.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.list,
    required this.members,
    required this.selected,
    required this.onTap,
  });

  final LocalList list;
  final List<LocalCandidate> members;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = KiteText.of(context);
    final c = KiteColors.of(context);
    return _SelectableSurface(
      selected: selected,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.muted,
                  borderRadius: KiteRadius.allMd,
                ),
                child: Text(
                  '${list.number}',
                  style: t.h4.copyWith(color: c.foreground),
                ),
              ),
              const SizedBox(width: KiteSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(list.name, style: t.h4),
                    if (list.slogan != null && list.slogan!.isNotEmpty)
                      Text(list.slogan!, style: t.muted),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: c.primary)
              else
                const Icon(Icons.radio_button_unchecked),
            ],
          ),
          if (members.isNotEmpty) ...[
            const SizedBox(height: KiteSpace.md),
            Wrap(
              spacing: KiteSpace.sm,
              runSpacing: KiteSpace.xs,
              children: [
                for (final member in members)
                  KiteBadge('${member.fullName} · ${member.position}'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SimpleCard extends StatelessWidget {
  const _SimpleCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = KiteText.of(context);
    final c = KiteColors.of(context);
    return _SelectableSurface(
      selected: selected,
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: selected ? c.primary : c.foreground),
          const SizedBox(width: KiteSpace.sm),
          Expanded(child: Text(label, style: t.h4)),
          if (selected)
            Icon(Icons.check_circle, color: c.primary)
          else
            const Icon(Icons.radio_button_unchecked),
        ],
      ),
    );
  }
}

class _SelectableSurface extends StatelessWidget {
  const _SelectableSurface({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = KiteColors.of(context);
    return Material(
      color: c.card,
      shape: RoundedRectangleBorder(
        borderRadius: KiteRadius.allLg,
        side: BorderSide(
          color: selected ? c.primary : c.border,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: KiteRadius.allLg,
        child: Padding(
          padding: const EdgeInsets.all(KiteSpace.lg),
          child: child,
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.enabled, required this.onContinue});

  final bool enabled;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final c = KiteColors.of(context);
    return Container(
      padding: const EdgeInsets.all(KiteSpace.lg),
      decoration: BoxDecoration(
        color: c.card,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.center,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: KiteButton(
              expands: true,
              enabled: enabled,
              onPressed: onContinue,
              trailing: const Icon(Icons.arrow_forward),
              child: const Text('Continuar'),
            ),
          ),
        ),
      ),
    );
  }
}
