import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../core/auth/auth_providers.dart';
import '../../shared/widgets/module_page.dart';
import '../../shared/widgets/table_helpers.dart';
import '../cursos/courses_providers.dart';
import '../cursos/data/courses_repository.dart';
import '../institucion/data/institution_repository.dart';
import '../institucion/institution_providers.dart';
import 'data/elections_repository.dart';
import 'elections_providers.dart';

/// Módulo F — Gestión de elecciones.
///
/// Crea elecciones, gestiona sus mesas, cambia de estado con confirmación y
/// genera la configuración descargable. Las transiciones sensibles quedan
/// auditadas por el backend.
class EleccionesScreen extends ConsumerWidget {
  const EleccionesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = KiteText.of(context);
    final institutionId = ref.watch(currentInstitutionIdProvider);
    final electionsAsync = ref.watch(electionsProvider);
    final years = ref.watch(academicYearsProvider).value ?? const <AcademicYear>[];
    final yearName = {for (final y in years) y.id: y.name};
    return ModulePage(
      title: 'Gestión de elecciones',
      description:
          'Cada elección pertenece a un año lectivo. Abrir una elección exige '
          'padrón, listas y dispositivos autorizados.',
      actions: [
        KiteButton(
          enabled: institutionId != null && years.isNotEmpty,
          onPressed: (institutionId == null || years.isEmpty)
              ? null
              : () => _openElectionForm(context, ref, institutionId, null),
          leading: const Icon(Icons.add, size: 16),
          child: const Text('Nueva elección'),
        ),
        KiteButton.outline(
          onPressed: () => ref.invalidate(electionsProvider),
          leading: const Icon(Icons.refresh, size: 16),
          child: const Text('Actualizar'),
        ),
      ],
      child: electionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => KiteAlert(
          title: 'No se pudieron cargar las elecciones',
          description: '$error',
          tone: KiteTone.danger,
        ),
        data: (list) {
          if (list.isEmpty) {
            return const KiteAlert(
              title: 'Sin elecciones',
              description:
                  'Crea una elección para configurar listas, mesas y '
                  'dispositivos.',
              tone: KiteTone.warning,
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${list.length} elecciones', style: t.muted),
              const SizedBox(height: KiteSpace.sm),
              Expanded(
                child: KiteDataTable(
                  columns: [
                    trinaTextColumn('Nombre', 'name', width: 240),
                    trinaTextColumn('Año lectivo', 'year', width: 140),
                    trinaTextColumn('Estado', 'status', width: 120),
                    trinaTextColumn(
                      'Versión',
                      'version',
                      width: 90,
                      align: TrinaColumnTextAlign.right,
                    ),
                    trinaTextColumn('Apertura', 'opens', width: 180),
                  ],
                  rows: [
                    for (final e in list)
                      trinaRow({
                        'name': e.name,
                        'year': yearName[e.academicYearId] ?? '—',
                        'status': electionStatusLabel(e.status),
                        'version': '${e.configVersion}',
                        'opens': _shortDateTime(e.opensAt),
                      }),
                  ],
                  onRowTap: (index) =>
                      _openElectionDetail(context, ref, list[index]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _shortDateTime(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

Future<void> _openElectionForm(
  BuildContext context,
  WidgetRef ref,
  String institutionId,
  Election? election,
) async {
  final saved = await kiteSheet<bool>(
    context,
    title: election == null ? 'Nueva elección' : 'Editar elección',
    description: 'Datos generales, normativa y ventana de la jornada.',
    width: 520,
    body: _ElectionForm(institutionId: institutionId, election: election),
  );
  if (saved != true) return;
  ref.invalidate(electionsProvider);
  if (context.mounted) {
    KiteToast.show(
      context,
      title: election == null ? 'Elección creada' : 'Elección actualizada',
      tone: KiteTone.success,
    );
  }
}

Future<void> _openElectionDetail(
  BuildContext context,
  WidgetRef ref,
  Election election,
) async {
  await kiteSheet<void>(
    context,
    title: election.name,
    description: 'Estado: ${electionStatusLabel(election.status)}',
    width: 560,
    body: _ElectionDetail(election: election),
  );
  ref.invalidate(electionsProvider);
}

class _ElectionForm extends ConsumerStatefulWidget {
  const _ElectionForm({required this.institutionId, this.election});

  final String institutionId;
  final Election? election;

  @override
  ConsumerState<_ElectionForm> createState() => _ElectionFormState();
}

class _ElectionFormState extends ConsumerState<_ElectionForm> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _normativa;
  String? _yearId;
  late String _timeZone;
  DateTime? _opensAt;
  DateTime? _closesAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final election = widget.election;
    _name = TextEditingController(text: election?.name ?? '');
    _description = TextEditingController(text: election?.description ?? '');
    _normativa = TextEditingController(text: election?.normativa ?? '');
    _yearId = election?.academicYearId;
    _timeZone = election?.timeZone ?? kTimeZones.first;
    _opensAt = election?.opensAt;
    _closesAt = election?.closesAt;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _normativa.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      KiteToast.show(
        context,
        title: 'El nombre de la elección es obligatorio',
        tone: KiteTone.danger,
      );
      return;
    }
    if (_yearId == null) {
      KiteToast.show(
        context,
        title: 'Selecciona un año lectivo',
        tone: KiteTone.danger,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(electionsRepositoryProvider);
      if (widget.election == null) {
        await repo.createElection(
          institutionId: widget.institutionId,
          academicYearId: _yearId!,
          name: name,
          description: _description.text,
          normativa: _normativa.text,
          timeZone: _timeZone,
          opensAt: _opensAt,
          closesAt: _closesAt,
        );
      } else {
        await repo.updateElection(
          widget.election!.id,
          name: name,
          description: _description.text,
          normativa: _normativa.text,
          timeZone: _timeZone,
          opensAt: _opensAt,
          closesAt: _closesAt,
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
    final years = ref.watch(academicYearsProvider).value ?? const <AcademicYear>[];
    final byId = {for (final y in years) y.id: y};
    final value = (_yearId != null && byId.containsKey(_yearId))
        ? _yearId
        : (years.isEmpty ? null : years.first.id);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KiteField(
            label: 'Nombre',
            child: KiteInput(
              controller: _name,
              placeholder: 'Por ejemplo, "Elección de personero 2025"',
            ),
          ),
          KiteField(
            label: 'Año lectivo',
            child: KiteSelect<String>(
              options: [for (final y in years) y.id],
              labelOf: (id) => byId[id]!.name,
              value: value,
              placeholder: 'Selecciona un año lectivo',
              onChanged: (v) => setState(() => _yearId = v),
            ),
          ),
          KiteField(
            label: 'Descripción (opcional)',
            child: KiteTextarea(controller: _description),
          ),
          KiteField(
            label: 'Normativa (opcional)',
            hint: 'Reglas de validez, mayoría, blancos y nulos.',
            child: KiteTextarea(controller: _normativa),
          ),
          KiteField(
            label: 'Zona horaria',
            child: KiteSelect<String>(
              options: kTimeZones,
              labelOf: (z) => z,
              value: _timeZone,
              onChanged: (v) => setState(() => _timeZone = v ?? _timeZone),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: KiteField(
                  label: 'Apertura',
                  child: KiteDatePicker(
                    selected: _opensAt,
                    placeholder: 'Fecha de apertura',
                    onChanged: (v) => setState(() => _opensAt = v),
                  ),
                ),
              ),
              const SizedBox(width: KiteSpace.md),
              Expanded(
                child: KiteField(
                  label: 'Cierre',
                  child: KiteDatePicker(
                    selected: _closesAt,
                    placeholder: 'Fecha de cierre',
                    onChanged: (v) => setState(() => _closesAt = v),
                  ),
                ),
              ),
            ],
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
      ),
    );
  }
}

class _ElectionDetail extends ConsumerStatefulWidget {
  const _ElectionDetail({required this.election});

  final Election election;

  @override
  ConsumerState<_ElectionDetail> createState() => _ElectionDetailState();
}

class _ElectionDetailState extends ConsumerState<_ElectionDetail> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _capacity = TextEditingController();
  String? _courseId;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _capacity.dispose();
    super.dispose();
  }

  Future<void> _transition(String status) async {
    final requiresConfirm = const {'open', 'closing', 'closed', 'archived', 'cancelled'};
    if (requiresConfirm.contains(status)) {
      final confirmed = await kiteConfirm(
        context,
        title: 'Cambiar estado a "${electionStatusLabel(status)}"',
        message:
            'Esta operación queda auditada. ¿Confirmas el cambio de estado?',
        confirmLabel: 'Confirmar',
      );
      if (!confirmed) return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(electionsRepositoryProvider)
          .transitionElection(widget.election.id, status);
      ref.invalidate(electionsProvider);
      if (!mounted) return;
      setState(() => _busy = false);
      KiteToast.show(
        context,
        title: 'Estado actualizado a ${electionStatusLabel(status)}',
        tone: KiteTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      KiteToast.show(
        context,
        title: 'No se pudo cambiar el estado',
        description: '$error',
        tone: KiteTone.danger,
      );
    }
  }

  Future<void> _generateConfig() async {
    setState(() => _busy = true);
    try {
      final hash = await ref
          .read(electionsRepositoryProvider)
          .generateConfig(widget.election.id);
      if (!mounted) return;
      setState(() => _busy = false);
      KiteToast.show(
        context,
        title: 'Configuración generada',
        description: 'Hash: $hash',
        tone: KiteTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      KiteToast.show(
        context,
        title: 'No se pudo generar la configuración',
        description: '$error',
        tone: KiteTone.danger,
      );
    }
  }

  Future<void> _addTable() async {
    final code = _code.text.trim();
    if (code.isEmpty) {
      KiteToast.show(
        context,
        title: 'El código de mesa es obligatorio',
        tone: KiteTone.danger,
      );
      return;
    }
    final capacity = _capacity.text.trim().isEmpty
        ? null
        : int.tryParse(_capacity.text.trim());
    try {
      await ref.read(electionsRepositoryProvider).createTable(
        electionId: widget.election.id,
        code: code,
        name: _name.text,
        capacity: capacity,
        courseId: _courseId,
      );
      _code.clear();
      _name.clear();
      _capacity.clear();
      setState(() => _courseId = null);
      ref.invalidate(electionTablesProvider(widget.election.id));
      if (mounted) {
        KiteToast.show(
          context,
          title: 'Mesa agregada',
          tone: KiteTone.success,
        );
      }
    } catch (error) {
      if (mounted) {
        KiteToast.show(
          context,
          title: 'No se pudo agregar la mesa',
          description: '$error',
          tone: KiteTone.danger,
        );
      }
    }
  }

  Future<void> _deleteTable(VotingTable table) async {
    final confirmed = await kiteConfirm(
      context,
      title: 'Eliminar mesa',
      message: 'Se eliminará la mesa "${table.code}".',
      confirmLabel: 'Eliminar',
    );
    if (!confirmed) return;
    try {
      await ref.read(electionsRepositoryProvider).deleteTable(table.id);
      ref.invalidate(electionTablesProvider(widget.election.id));
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
    final election = widget.election;
    final tablesAsync = ref.watch(electionTablesProvider(election.id));
    final reconAsync = ref.watch(electionReconciliationProvider(election.id));
    final courses =
        ref.watch(coursesProvider(election.academicYearId)).value ??
        const <Course>[];
    final courseOptions = <Course>[
      const Course(
        id: '',
        academicYearId: '',
        grade: '',
        parallel: '',
        displayName: 'Sin curso',
      ),
      ...courses,
    ];
    final next = nextElectionStatuses(election.status);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DetailRow(label: 'Estado', value: electionStatusLabel(election.status)),
          DetailRow(label: 'Versión de configuración', value: '${election.configVersion}'),
          DetailRow(label: 'Zona horaria', value: election.timeZone),
          DetailRow(label: 'Apertura', value: _shortDateTime(election.opensAt)),
          DetailRow(label: 'Cierre', value: _shortDateTime(election.closesAt)),
          if (election.normativa != null && election.normativa!.isNotEmpty)
            DetailRow(label: 'Normativa', value: election.normativa!),
          const SizedBox(height: KiteSpace.lg),
          _Reconciliation(electionId: election.id),
          const SizedBox(height: KiteSpace.lg),
          if (next.isNotEmpty) ...[
            Text('Cambiar estado', style: t.small.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: KiteSpace.sm),
            for (final status in next)
              if ((status == 'closing' || status == 'closed') &&
                  !(reconAsync.value?.readyToClose ?? false))
                Padding(
                  padding: const EdgeInsets.only(bottom: KiteSpace.xs),
                  child: Text(
                    'No se puede cerrar: hay votos pendientes o incidencias sin '
                    'resolver. Concílialos primero.',
                    style: t.muted,
                  ),
                ),
            Wrap(
              spacing: KiteSpace.sm,
              runSpacing: KiteSpace.sm,
              children: [
                for (final status in next)
                  status == 'cancelled'
                      ? KiteButton.destructive(
                          enabled: !_busy,
                          onPressed: () => _transition(status),
                          child: Text(electionStatusLabel(status)),
                        )
                      : KiteButton.outline(
                          enabled: !_busy &&
                              !((status == 'closing' || status == 'closed') &&
                                  !(reconAsync.value?.readyToClose ?? false)),
                          onPressed: () => _transition(status),
                          child: Text('→ ${electionStatusLabel(status)}'),
                        ),
              ],
            ),
            const SizedBox(height: KiteSpace.lg),
          ],
          KiteButton.secondary(
            enabled: !_busy,
            onPressed: _generateConfig,
            leading: const Icon(Icons.build_outlined, size: 16),
            child: const Text('Generar configuración descargable'),
          ),
          const SizedBox(height: KiteSpace.xl),
          Text('Mesas', style: t.small.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: KiteSpace.sm),
          tablesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: KiteSpace.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => KiteAlert(
              title: 'No se pudieron cargar las mesas',
              description: '$error',
              tone: KiteTone.danger,
            ),
            data: (tables) => Column(
              children: [
                if (tables.isEmpty)
                  Text('Sin mesas registradas.', style: t.muted)
                else
                  for (final table in tables)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${table.code} · ${table.name ?? 'Mesa'}'
                              '${table.capacity == null ? '' : ' (cap. ${table.capacity})'}',
                              style: t.small,
                            ),
                          ),
                          IconButton(
                            onPressed: () => _deleteTable(table),
                            icon: const Icon(Icons.delete_outline, size: 16),
                            tooltip: 'Eliminar',
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: KiteSpace.md),
          Text('Agregar mesa', style: t.muted),
          const SizedBox(height: KiteSpace.sm),
          Row(
            children: [
              Expanded(
                child: KiteInput(controller: _code, placeholder: 'Código'),
              ),
              const SizedBox(width: KiteSpace.sm),
              Expanded(
                child: KiteInput(controller: _name, placeholder: 'Nombre'),
              ),
              const SizedBox(width: KiteSpace.sm),
              SizedBox(
                width: 100,
                child: KiteInput(
                  controller: _capacity,
                  placeholder: 'Capacidad',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: KiteSpace.sm),
          KiteSelect<Course>(
            options: courseOptions,
            labelOf: (c) => c.id.isEmpty ? 'Sin curso' : c.displayName,
            value: courseOptions.firstWhere(
              (c) => c.id == (_courseId ?? ''),
              orElse: () => courseOptions.first,
            ),
            onChanged: (value) => setState(() {
              _courseId = (value == null || value.id.isEmpty) ? null : value.id;
            }),
          ),
          const SizedBox(height: KiteSpace.sm),
          Align(
            alignment: Alignment.centerRight,
            child: KiteButton(
              onPressed: _addTable,
              leading: const Icon(Icons.add, size: 16),
              child: const Text('Agregar mesa'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Panel de conciliación: pendientes, conflictos e incidencias abiertas.
class _Reconciliation extends ConsumerWidget {
  const _Reconciliation({required this.electionId});

  final String electionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = KiteText.of(context);
    final reconAsync = ref.watch(electionReconciliationProvider(electionId));
    return reconAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => KiteAlert(
        title: 'No se pudo cargar la conciliación',
        description: '$error',
        tone: KiteTone.danger,
      ),
      data: (recon) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Conciliación', style: t.small.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: KiteSpace.sm),
          DetailRow(
            label: 'Operaciones pendientes',
            value: '${recon.pendingOperations}',
          ),
          DetailRow(
            label: 'Conflictos por conciliar',
            value: '${recon.conflictOperations}',
          ),
          DetailRow(
            label: 'Incidencias abiertas',
            value: '${recon.openIncidents}',
          ),
          const SizedBox(height: KiteSpace.sm),
          KiteAlert(
            title: recon.readyToClose ? 'Lista para cerrar' : 'Cierre bloqueado',
            description: recon.readyToClose
                ? 'No hay votos pendientes ni incidencias sin resolver.'
                : 'Sincroniza los dispositivos y resuelve las incidencias '
                    'antes de cerrar la elección.',
            tone: recon.readyToClose ? KiteTone.success : KiteTone.warning,
          ),
        ],
      ),
    );
  }
}
