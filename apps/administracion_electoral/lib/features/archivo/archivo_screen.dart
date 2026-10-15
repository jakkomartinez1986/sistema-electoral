import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../shared/export/acta_exporter.dart';
import '../../shared/widgets/module_page.dart';
import '../../shared/widgets/table_helpers.dart';
import '../elecciones/data/elections_repository.dart';
import '../elecciones/elections_providers.dart';
import '../institucion/data/institution_repository.dart';
import '../institucion/institution_providers.dart';
import '../listas/data/lists_repository.dart';
import '../listas/lists_providers.dart';
import '../resultados/acta_builder.dart';
import '../resultados/data/results_repository.dart';
import '../resultados/results_providers.dart';
import 'archive_providers.dart';
import 'data/archive_repository.dart';

/// Módulo J — Archivo.
///
/// Histórico de elecciones cerradas o archivadas agrupadas por año lectivo,
/// consulta de resultados congelados y registro de auditoría institucional.
class ArchivoScreen extends ConsumerWidget {
  const ArchivoScreen({super.key});

  static final _date = DateFormat('yyyy-MM-dd HH:mm');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final electionsAsync = ref.watch(electionsProvider);
    final years = ref.watch(academicYearsProvider).value ??
        const <AcademicYear>[];
    final audit = ref.watch(auditLogsProvider);
    return ModulePage(
      title: 'Archivo',
      description:
          'Elecciones cerradas y archivadas, sus resultados congelados y el '
          'registro de auditoría de la institución.',
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          electionsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: KiteSpace.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => KiteAlert(
              title: 'No se pudieron cargar las elecciones',
              description: '$error',
              tone: KiteTone.danger,
            ),
            data: (elections) {
              final archived = elections
                  .where((e) => e.status == 'closed' || e.status == 'archived')
                  .toList();
              if (archived.isEmpty) {
                return const KiteAlert(
                  title: 'Archivo vacío',
                  description:
                      'Aún no hay elecciones cerradas ni archivadas.',
                  tone: KiteTone.info,
                );
              }
              final byYear = <String, List<Election>>{};
              for (final election in archived) {
                byYear.putIfAbsent(election.academicYearId, () => []).add(election);
              }
              final yearName = {for (final y in years) y.id: y.name};
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final entry in byYear.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: KiteSpace.sm),
                      child: Text(
                        yearName[entry.key] ?? 'Año lectivo',
                        style: KiteText.of(context).large,
                      ),
                    ),
                    KiteCard(
                      child: SizedBox(
                        height: 240,
                        child: KiteDataTable(
                          columns: [
                            trinaTextColumn('Elección', 'name', width: 260),
                            trinaTextColumn('Estado', 'status', width: 130),
                            trinaTextColumn('Cierre', 'closed', width: 160),
                          ],
                          rows: [
                            for (final election in entry.value)
                              trinaRow({
                                'name': election.name,
                                'status': electionStatusLabel(election.status),
                                'closed': election.closesAt == null
                                    ? '—'
                                    : _date.format(election.closesAt!.toLocal()),
                              }),
                          ],
                          onRowTap: (index) => _showResults(
                            context,
                            entry.value[index],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: KiteSpace.xl),
                  ],
                ],
              );
            },
          ),
          KiteCard(
            title: 'Auditoría',
            child: audit.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: KiteSpace.lg),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => KiteAlert(
                title: 'No se pudo cargar la auditoría',
                description: '$error',
                tone: KiteTone.danger,
              ),
              data: (logs) {
                if (logs.isEmpty) {
                  return Text(
                    'Sin eventos de auditoría.',
                    style: KiteText.of(context).muted,
                  );
                }
                return SizedBox(
                  height: 320,
                  child: KiteDataTable(
                    columns: [
                      trinaTextColumn('Acción', 'action', width: 260),
                      trinaTextColumn('Objeto', 'target', width: 160),
                      trinaTextColumn('Fecha', 'date', width: 180),
                    ],
                    rows: [
                      for (final AuditEntry log in logs)
                        trinaRow({
                          'action': log.action,
                          'target': log.targetType ?? '—',
                          'date': log.createdAt == null
                              ? '—'
                              : _date.format(log.createdAt!.toLocal()),
                        }),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showResults(BuildContext context, Election election) {
    return kiteSheet<void>(
      context,
      title: 'Resultados — ${election.name}',
      description: 'Cifras congeladas de la elección '
          '(${electionStatusLabel(election.status)}).',
      width: 560,
      body: _ArchivedResults(election: election),
    );
  }
}

class _ArchivedResults extends ConsumerWidget {
  const _ArchivedResults({required this.election});

  final Election election;

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    ElectionTotals totals, {
    required bool pdf,
  }) async {
    try {
      final data = await buildActaData(ref, election: election, totals: totals);
      final path = pdf
          ? await const ActaExporter().savePdf(data)
          : await const ActaExporter().saveExcel(data);
      if (!context.mounted || path == null) return;
      KiteToast.show(
        context,
        title: 'Acta guardada',
        description: path,
        tone: KiteTone.success,
      );
    } catch (error) {
      if (!context.mounted) return;
      KiteToast.show(
        context,
        title: 'No se pudo exportar el acta',
        description: '$error',
        tone: KiteTone.danger,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalsAsync = ref.watch(electionTotalsProvider(election.id));
    final lists = ref.watch(candidateListsProvider(election.id)).value ??
        const <CandidateList>[];
    return totalsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => KiteAlert(
        title: 'No se pudieron cargar los resultados',
        description: '$error',
        tone: KiteTone.danger,
      ),
      data: (totals) {
        final ordered = lists
            .where((l) => totals.byList.containsKey(l.id))
            .map((l) => MapEntry(l, totals.byList[l.id]!))
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        return ListView(
          shrinkWrap: true,
          children: [
            Row(
              children: [
                KiteButton.outline(
                  onPressed: () => _export(context, ref, totals, pdf: true),
                  leading: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                  child: const Text('Acta (PDF)'),
                ),
                const SizedBox(width: KiteSpace.sm),
                KiteButton.outline(
                  onPressed: () => _export(context, ref, totals, pdf: false),
                  leading: const Icon(Icons.table_view_outlined, size: 16),
                  child: const Text('Resultados (Excel)'),
                ),
              ],
            ),
            const SizedBox(height: KiteSpace.lg),
            DetailRow(label: 'Votos válidos', value: '${totals.validVotes}'),
            DetailRow(label: 'En blanco', value: '${totals.blank}'),
            DetailRow(label: 'Nulos', value: '${totals.nullVotes}'),
            DetailRow(label: 'Total escrutado', value: '${totals.cast}'),
            const SizedBox(height: KiteSpace.lg),
            for (final entry in ordered)
              DetailRow(
                label: '${entry.key.number}. ${entry.key.name}',
                value: '${entry.value}',
              ),
          ],
        );
      },
    );
  }
}
