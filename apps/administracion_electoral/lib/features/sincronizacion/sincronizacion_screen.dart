import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../shared/widgets/module_page.dart';
import '../../shared/widgets/table_helpers.dart';
import '../elecciones/data/elections_repository.dart';
import '../elecciones/elections_providers.dart';
import 'data/sync_repository.dart';
import 'sync_providers.dart';

/// Módulo H — Sincronización y conciliación.
///
/// Muestra operaciones por estado, participación agregada por mesa e
/// incidencias. Nunca muestra la identidad del votante ni el contenido del voto.
class SincronizacionScreen extends ConsumerWidget {
  const SincronizacionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final electionsAsync = ref.watch(electionsProvider);
    final selectedId = ref.watch(selectedElectionIdProvider);
    return ModulePage(
      title: 'Sincronización y conciliación',
      description:
          'Votos recibidos y participación (sin identidades), operaciones '
          'aceptadas/rechazadas e incidencias de la elección seleccionada.',
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
                  'Crea una elección y autoriza dispositivos para ver su '
                  'conciliación.',
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
                      labelOf: (id) =>
                          elections.firstWhere((e) => e.id == id).name,
                      value: effectiveId,
                      onChanged: (value) => ref
                          .read(selectedElectionIdProvider.notifier)
                          .set(value ?? effectiveId),
                    ),
                  ),
                  const Spacer(),
                  KiteButton.outline(
                    onPressed: () {
                      ref.invalidate(syncCountsProvider(effectiveId));
                      ref.invalidate(participationByTableProvider(effectiveId));
                      ref.invalidate(incidentsProvider(effectiveId));
                    },
                    leading: const Icon(Icons.refresh, size: 16),
                    child: const Text('Actualizar'),
                  ),
                ],
              ),
              const SizedBox(height: KiteSpace.lg),
              Expanded(child: _SyncBody(electionId: effectiveId)),
            ],
          );
        },
      ),
    );
  }
}

class _SyncBody extends ConsumerWidget {
  const _SyncBody({required this.electionId});

  final String electionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = KiteText.of(context);
    final countsAsync = ref.watch(syncCountsProvider(electionId));
    final participation = ref.watch(participationByTableProvider(electionId));
    final incidents = ref.watch(incidentsProvider(electionId));
    final tables =
        ref.watch(electionTablesProvider(electionId)).value ??
        const <VotingTable>[];
    final tableName = {for (final v in tables) v.id: v.code};

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        countsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: KiteSpace.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => KiteAlert(
            title: 'No se pudieron cargar los contadores',
            description: '$error',
            tone: KiteTone.danger,
          ),
          data: (c) => KiteStatGrid(
            children: [
              KiteStat(label: 'Operaciones aceptadas', value: '${c.accepted}'),
              KiteStat(
                label: 'Pendientes',
                value: '${c.pending}',
                delta: c.pending > 0 ? 'por conciliar' : null,
                deltaTone: KiteTone.warning,
              ),
              KiteStat(
                label: 'Rechazadas',
                value: '${c.rejected}',
                delta: c.rejected > 0 ? 'requieren revisión' : null,
                deltaTone: KiteTone.danger,
              ),
              KiteStat(
                label: 'Conflictos',
                value: '${c.conflict}',
                delta: c.conflict > 0 ? 'duplicados o config' : null,
                deltaTone: KiteTone.danger,
              ),
              KiteStat(label: 'Participación registrada', value: '${c.participation}'),
            ],
          ),
        ),
        const SizedBox(height: KiteSpace.xl),
        KiteCard(
          title: 'Participación por mesa',
          child: participation.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: KiteSpace.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => KiteAlert(
              title: 'No se pudo cargar la participación',
              description: '$error',
              tone: KiteTone.danger,
            ),
            data: (map) {
              if (map.isEmpty) {
                return Text('Sin participación registrada.', style: t.muted);
              }
              final entries = map.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              return Column(
                children: [
                  for (final entry in entries)
                    DetailRow(
                      label: entry.key == null
                          ? 'Sin mesa'
                          : (tableName[entry.key] ?? 'Mesa'),
                      value: '${entry.value}',
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: KiteSpace.xl),
        KiteCard(
          title: 'Incidencias',
          child: incidents.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: KiteSpace.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => KiteAlert(
              title: 'No se pudieron cargar las incidencias',
              description: '$error',
              tone: KiteTone.danger,
            ),
            data: (list) {
              if (list.isEmpty) {
                return Text('Sin incidencias registradas.', style: t.muted);
              }
              return SizedBox(
                height: 280,
                child: KiteDataTable(
                  columns: [
                    trinaTextColumn('Tipo', 'kind', width: 160),
                    trinaTextColumn('Estado', 'status', width: 140),
                    trinaTextColumn('Descripción', 'description', width: 320),
                  ],
                  rows: [
                    for (final incident in list)
                      trinaRow({
                        'kind': incident.kind,
                        'status': incidentStatusLabel(incident.status),
                        'description': incident.description ?? '—',
                      }),
                  ],
                  onRowTap: (index) =>
                      _openIncident(context, ref, electionId, list[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

Future<void> _openIncident(
  BuildContext context,
  WidgetRef ref,
  String electionId,
  Incident incident,
) async {
  final saved = await kiteSheet<bool>(
    context,
    title: 'Incidencia: ${incident.kind}',
    description: incident.description ?? 'Sin descripción.',
    body: _IncidentForm(incident: incident),
  );
  if (saved != true) return;
  ref.invalidate(incidentsProvider(electionId));
  if (context.mounted) {
    KiteToast.show(
      context,
      title: 'Incidencia actualizada',
      tone: KiteTone.success,
    );
  }
}

class _IncidentForm extends ConsumerStatefulWidget {
  const _IncidentForm({required this.incident});

  final Incident incident;

  @override
  ConsumerState<_IncidentForm> createState() => _IncidentFormState();
}

class _IncidentFormState extends ConsumerState<_IncidentForm> {
  late final TextEditingController _resolution;
  late String _status;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _resolution = TextEditingController(text: widget.incident.resolution ?? '');
    _status = widget.incident.status;
  }

  @override
  void dispose() {
    _resolution.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(syncRepositoryProvider).updateIncident(
        id: widget.incident.id,
        status: _status,
        resolution: _resolution.text,
      );
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
        DetailRow(label: 'Tipo', value: widget.incident.kind),
        DetailRow(label: 'Descripción', value: widget.incident.description ?? '—'),
        KiteField(
          label: 'Estado',
          child: KiteSelect<String>(
            options: kIncidentStatuses,
            labelOf: incidentStatusLabel,
            value: _status,
            onChanged: (value) => setState(() => _status = value ?? _status),
          ),
        ),
        KiteField(
          label: 'Resolución',
          hint: 'Procedimiento aplicado. Queda registrado en auditoría.',
          child: KiteTextarea(controller: _resolution),
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