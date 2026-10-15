import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../shared/widgets/module_page.dart';
import '../../shared/widgets/table_helpers.dart';
import '../elecciones/data/elections_repository.dart';
import '../elecciones/elections_providers.dart';
import 'data/lists_repository.dart';
import 'lists_providers.dart';

/// Módulo E — Listas y candidatos.
///
/// La oferta electoral es de cantidad variable. Al abrir la elección, la oferta
/// queda congelada: el backend rechaza modificaciones de listas habilitadas
/// durante la jornada.
class ListasScreen extends ConsumerWidget {
  const ListasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = KiteText.of(context);
    final electionsAsync = ref.watch(electionsProvider);
    final selectedId = ref.watch(selectedElectionIdProvider);
    return ModulePage(
      title: 'Listas y candidatos',
      description:
          'Listas, candidatos y su habilitación para cada elección. Operan '
          'sobre la elección seleccionada.',
      child: electionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => KiteAlert(
          title: 'No se pudieron cargar las elecciones',
          description: '$error',
          tone: KiteTone.danger,
        ),
        data: (elections) {
          if (elections.isEmpty) {
            return const KiteAlert(
              title: 'Sin elecciones',
              description:
                  'Crea una elección en el módulo "Gestión de elecciones" '
                  'antes de definir listas.',
              tone: KiteTone.warning,
            );
          }
          final effectiveId = elections.any((e) => e.id == selectedId)
              ? selectedId!
              : elections.first.id;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 320,
                    child: KiteSelect<String>(
                      options: [for (final e in elections) e.id],
                      labelOf: (id) => elections
                          .firstWhere((e) => e.id == id)
                          .name,
                      value: effectiveId,
                      onChanged: (value) => ref
                          .read(selectedElectionIdProvider.notifier)
                          .set(value ?? effectiveId),
                    ),
                  ),
                  const SizedBox(width: KiteSpace.md),
                  Text(
                    electionStatusLabel(
                      elections.firstWhere((e) => e.id == effectiveId).status,
                    ),
                    style: t.muted,
                  ),
                  const Spacer(),
                  KiteButton(
                    onPressed: () => _openListForm(
                      context,
                      ref,
                      effectiveId,
                      null,
                    ),
                    leading: const Icon(Icons.add, size: 16),
                    child: const Text('Nueva lista'),
                  ),
                  KiteButton.outline(
                    onPressed: () =>
                        ref.invalidate(candidateListsProvider(effectiveId)),
                    leading: const Icon(Icons.refresh, size: 16),
                    child: const Text('Actualizar'),
                  ),
                ],
              ),
              const SizedBox(height: KiteSpace.sm),
              Expanded(
                child: _ListsTable(electionId: effectiveId),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ListsTable extends ConsumerWidget {
  const _ListsTable({required this.electionId});

  final String electionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = KiteText.of(context);
    final listsAsync = ref.watch(candidateListsProvider(electionId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${listsAsync.value?.length ?? 0} listas', style: t.muted),
        const SizedBox(height: KiteSpace.sm),
        Expanded(
          child: listsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => KiteAlert(
              title: 'No se pudieron cargar las listas',
              description: '$error',
              tone: KiteTone.danger,
            ),
            data: (list) {
              if (list.isEmpty) {
                return Center(
                  child: Text('Sin listas. Crea la primera.', style: t.muted),
                );
              }
              return KiteDataTable(
                columns: [
                  trinaTextColumn(
                    'N.º',
                    'number',
                    width: 80,
                    align: TrinaColumnTextAlign.center,
                  ),
                  trinaTextColumn('Nombre', 'name', width: 220),
                  trinaTextColumn('Lema', 'slogan', width: 240),
                  trinaTextColumn('Estado', 'enabled', width: 110),
                ],
                rows: [
                  for (final l in list)
                    trinaRow({
                      'number': '${l.number}',
                      'name': l.name,
                      'slogan': l.slogan ?? '—',
                      'enabled': l.enabled ? 'Habilitada' : 'Deshabilitada',
                    }),
                ],
                onRowTap: (index) => _openListDetail(context, ref, list[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

Future<void> _openListForm(
  BuildContext context,
  WidgetRef ref,
  String electionId,
  CandidateList? list,
) async {
  final saved = await kiteSheet<bool>(
    context,
    title: list == null ? 'Nueva lista' : 'Editar lista',
    description: 'Número, nombre y lema.',
    body: _ListForm(electionId: electionId, list: list),
  );
  if (saved != true) return;
  ref.invalidate(candidateListsProvider(electionId));
  if (context.mounted) {
    KiteToast.show(
      context,
      title: list == null ? 'Lista creada' : 'Lista actualizada',
      tone: KiteTone.success,
    );
  }
}

class _ListForm extends ConsumerStatefulWidget {
  const _ListForm({required this.electionId, this.list});

  final String electionId;
  final CandidateList? list;

  @override
  ConsumerState<_ListForm> createState() => _ListFormState();
}

class _ListFormState extends ConsumerState<_ListForm> {
  late final TextEditingController _number;
  late final TextEditingController _name;
  late final TextEditingController _slogan;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final list = widget.list;
    _number = TextEditingController(text: list == null ? '' : '${list.number}');
    _name = TextEditingController(text: list?.name ?? '');
    _slogan = TextEditingController(text: list?.slogan ?? '');
  }

  @override
  void dispose() {
    _number.dispose();
    _name.dispose();
    _slogan.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final number = int.tryParse(_number.text.trim());
    final name = _name.text.trim();
    if (number == null || name.isEmpty) {
      KiteToast.show(
        context,
        title: 'Número y nombre son obligatorios',
        tone: KiteTone.danger,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(listsRepositoryProvider);
      if (widget.list == null) {
        await repo.createList(
          electionId: widget.electionId,
          number: number,
          name: name,
          slogan: _slogan.text,
        );
      } else {
        await repo.updateList(
          widget.list!.id,
          number: number,
          name: name,
          slogan: _slogan.text,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      KiteToast.show(
        context,
        title: 'No se pudo guardar',
        description: '$error',
        tone: KiteTone.danger,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KiteField(
          label: 'Número de lista',
          child: KiteInput(
            controller: _number,
            placeholder: 'Por ejemplo, 1 o 2',
            keyboardType: TextInputType.number,
          ),
        ),
        KiteField(
          label: 'Nombre',
          child: KiteInput(controller: _name, placeholder: 'Lista A'),
        ),
        KiteField(
          label: 'Lema (opcional)',
          child: KiteTextarea(controller: _slogan),
        ),
        const SizedBox(height: KiteSpace.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            KiteButton.outline(
              enabled: !_saving,
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            const SizedBox(width: KiteSpace.sm),
            KiteButton(
              enabled: !_saving,
              onPressed: _save,
              child: Text(_saving ? 'Guardando…' : 'Guardar'),
            ),
          ],
        ),
      ],
    );
  }
}

Future<void> _openListDetail(
  BuildContext context,
  WidgetRef ref,
  CandidateList list,
) async {
  await kiteSheet<void>(
    context,
    title: 'Lista ${list.number} · ${list.name}',
    description: 'Datos de la lista, habilitación y candidatos.',
    width: 520,
    body: _ListDetail(list: list),
  );
  ref.invalidate(candidateListsProvider(list.electionId));
}

class _ListDetail extends ConsumerStatefulWidget {
  const _ListDetail({required this.list});

  final CandidateList list;

  @override
  ConsumerState<_ListDetail> createState() => _ListDetailState();
}

class _ListDetailState extends ConsumerState<_ListDetail> {
  final _candidateName = TextEditingController();
  final _candidatePosition = TextEditingController();
  bool _enabled = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _enabled = widget.list.enabled;
  }

  @override
  void dispose() {
    _candidateName.dispose();
    _candidatePosition.dispose();
    super.dispose();
  }

  Future<void> _toggleEnabled(bool value) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(listsRepositoryProvider)
          .setListEnabled(widget.list.id, value);
      if (!mounted) return;
      setState(() {
        _enabled = value;
        _busy = false;
      });
      ref.invalidate(candidateListsProvider(widget.list.electionId));
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      KiteToast.show(
        context,
        title: 'No se pudo cambiar la habilitación',
        description: '$error',
        tone: KiteTone.danger,
      );
    }
  }

  Future<void> _addCandidate() async {
    final name = _candidateName.text.trim();
    final position = _candidatePosition.text.trim();
    if (name.isEmpty || position.isEmpty) {
      KiteToast.show(
        context,
        title: 'Nombre y cargo del candidato son obligatorios',
        tone: KiteTone.danger,
      );
      return;
    }
    try {
      await ref.read(listsRepositoryProvider).createCandidate(
        listId: widget.list.id,
        fullName: name,
        position: position,
      );
      _candidateName.clear();
      _candidatePosition.clear();
      if (!mounted) return;
      setState(() {});
      ref.invalidate(candidatesProvider(widget.list.id));
    } catch (error) {
      if (mounted) {
        KiteToast.show(
          context,
          title: 'No se pudo agregar el candidato',
          description: '$error',
          tone: KiteTone.danger,
        );
      }
    }
  }

  Future<void> _deleteCandidate(CandidateItem candidate) async {
    final confirmed = await kiteConfirm(
      context,
      title: 'Eliminar candidato',
      message: 'Se eliminará a "${candidate.fullName}".',
      confirmLabel: 'Eliminar',
    );
    if (!confirmed) return;
    try {
      await ref
          .read(listsRepositoryProvider)
          .deleteCandidate(candidate.id);
      ref.invalidate(candidatesProvider(widget.list.id));
    } catch (error) {
      if (mounted) {
        KiteToast.show(
          context,
          title: 'No se pudo eliminar',
          description: '$error',
          tone: KiteTone.danger,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = KiteText.of(context);
    final list = widget.list;
    final candidatesAsync = ref.watch(candidatesProvider(list.id));
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DetailRow(label: 'Número', value: '${list.number}'),
          DetailRow(label: 'Nombre', value: list.name),
          if (list.slogan != null)
            DetailRow(label: 'Lema', value: list.slogan!),
          KiteSwitch(
            value: _enabled,
            label: 'Habilitada',
            sublabel:
                'Deshabilitarla la retira de la configuración descargable y '
                'del escrutinio.',
            onChanged: _busy ? null : _toggleEnabled,
          ),
          const SizedBox(height: KiteSpace.xl),
          Text('Candidatos', style: t.small.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: KiteSpace.sm),
          candidatesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: KiteSpace.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => KiteAlert(
              title: 'No se pudieron cargar los candidatos',
              description: '$error',
              tone: KiteTone.danger,
            ),
            data: (candidates) {
              if (candidates.isEmpty) {
                return Text('Sin candidatos registrados.', style: t.muted);
              }
              return Column(
                children: [
                  for (final candidate in candidates)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${candidate.fullName} · ${candidate.position}',
                              style: t.small,
                            ),
                          ),
                          IconButton(
                            onPressed: () => _deleteCandidate(candidate),
                            icon: const Icon(Icons.delete_outline, size: 16),
                            tooltip: 'Eliminar candidato',
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: KiteSpace.md),
          Text('Agregar candidato', style: t.muted),
          const SizedBox(height: KiteSpace.sm),
          Row(
            children: [
              Expanded(
                child: KiteInput(
                  controller: _candidateName,
                  placeholder: 'Nombre completo',
                ),
              ),
              const SizedBox(width: KiteSpace.sm),
              Expanded(
                child: KiteInput(
                  controller: _candidatePosition,
                  placeholder: 'Cargo',
                ),
              ),
              const SizedBox(width: KiteSpace.sm),
              KiteButton(
                onPressed: _addCandidate,
                leading: const Icon(Icons.add, size: 16),
                child: const Text('Agregar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}