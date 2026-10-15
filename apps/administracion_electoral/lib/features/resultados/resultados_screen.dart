import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../shared/export/acta_exporter.dart';
import '../../shared/widgets/module_page.dart';
import '../../shared/widgets/table_helpers.dart';
import '../elecciones/data/elections_repository.dart';
import '../elecciones/elections_providers.dart';
import '../listas/data/lists_repository.dart';
import '../listas/lists_providers.dart';
import '../sincronizacion/sync_providers.dart';
import 'acta_builder.dart';
import 'chart_data.dart';
import 'data/results_repository.dart';
import 'results_providers.dart';

/// Módulo I — Resultados.
///
/// Solo expone agregados y únicamente cuando la elección está cerrada o
/// archivada: mientras esté abierta no se muestran cifras de voto.
class ResultadosScreen extends ConsumerWidget {
  const ResultadosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final electionsAsync = ref.watch(electionsProvider);
    final selectedId = ref.watch(selectedElectionIdProvider);
    return ModulePage(
      title: 'Resultados',
      description:
          'Votos válidos, en blanco y nulos por lista. Disponible cuando la '
          'elección está cerrada.',
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
              description: 'Crea y cierra una elección para ver sus resultados.',
              tone: KiteTone.warning,
            );
          }
          final effectiveId = elections.any((e) => e.id == selectedId)
              ? selectedId!
              : elections.first.id;
          final election =
              elections.firstWhere((e) => e.id == effectiveId);
          final published = election.status == 'closed' ||
              election.status == 'archived';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(height: KiteSpace.lg),
              Expanded(
                child: published
                    ? _ResultsBody(election: election)
                    : KiteAlert(
                        title: 'Resultados no publicados',
                        description:
                            'La elección «${election.name}» está en estado '
                            '«${electionStatusLabel(election.status)}». Las '
                            'cifras se muestran solo cuando está cerrada.',
                        tone: KiteTone.warning,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ResultsBody extends ConsumerWidget {
  const _ResultsBody({required this.election});

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
    final counts = ref.watch(syncCountsProvider(election.id)).value;

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
        final valid = totals.validVotes;
        final distribution = voteDistribution(
          lists: [
            for (final entry in ordered)
              VoteCount(
                label: '${entry.key.number}. ${entry.key.name}',
                votes: entry.value,
              ),
          ],
          blank: totals.blank,
          nullVotes: totals.nullVotes,
        );
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            Row(
              children: [
                KiteButton.outline(
                  onPressed: () => _export(context, ref, totals, pdf: true),
                  leading: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                  child: const Text('Exportar acta (PDF)'),
                ),
                const SizedBox(width: KiteSpace.sm),
                KiteButton.outline(
                  onPressed: () => _export(context, ref, totals, pdf: false),
                  leading: const Icon(Icons.table_view_outlined, size: 16),
                  child: const Text('Exportar resultados (Excel)'),
                ),
              ],
            ),
            const SizedBox(height: KiteSpace.lg),
            KiteStatGrid(
              children: [
                KiteStat(label: 'Votos válidos', value: '$valid'),
                KiteStat(label: 'En blanco', value: '${totals.blank}'),
                KiteStat(label: 'Nulos', value: '${totals.nullVotes}'),
                KiteStat(label: 'Total escrutado', value: '${totals.cast}'),
                KiteStat(
                  label: 'Participación',
                  value: counts == null ? '—' : '${counts.participation}',
                  delta: counts == null
                      ? null
                      : '${counts.issued} operaciones',
                ),
              ],
            ),
            const SizedBox(height: KiteSpace.xl),
            KiteCard(
              title: 'Informe gráfico',
              child: totals.cast == 0
                  ? Text(
                      'Sin votos registrados.',
                      style: KiteText.of(context).muted,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        KiteDonut(
                          slices: [
                            for (var i = 0; i < distribution.length; i++)
                              KiteSlice(
                                label: distribution[i].label,
                                value: distribution[i].votes.toDouble(),
                                color: distribution[i].isList
                                    ? KiteChartPalette.at(i)
                                    : (distribution[i].label == 'Nulos'
                                          ? KiteChartPalette.nullVote
                                          : KiteChartPalette.blank),
                              ),
                          ],
                          centerLabel: 'Total escrutado',
                          centerValue: '${totals.cast}',
                        ),
                        const SizedBox(height: KiteSpace.xl),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: KiteSpace.xs,
                          ),
                          child: KiteBarChart(
                            bars: [
                              for (var i = 0; i < ordered.length; i++)
                                KiteBar(
                                  label: '${ordered[i].key.number}',
                                  value: ordered[i].value.toDouble(),
                                  color: KiteChartPalette.at(i),
                                  tooltip:
                                      '${ordered[i].key.number}. '
                                      '${ordered[i].key.name}',
                                ),
                              if (totals.blank > 0)
                                KiteBar(
                                  label: 'B',
                                  value: totals.blank.toDouble(),
                                  color: KiteChartPalette.blank,
                                  tooltip: 'En blanco',
                                ),
                              if (totals.nullVotes > 0)
                                KiteBar(
                                  label: 'N',
                                  value: totals.nullVotes.toDouble(),
                                  color: KiteChartPalette.nullVote,
                                  tooltip: 'Nulos',
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: KiteSpace.xl),
            KiteCard(
              title: 'Distribución de votos válidos',
              child: valid == 0
                  ? Text('Sin votos válidos registrados.', style: KiteText.of(context).muted)
                  : Column(
                      children: [
                        for (final entry in ordered)
                          KiteMeter(
                            label: '${entry.key.number}. ${entry.key.name}',
                            value: entry.value / valid,
                            trailing:
                                '${entry.value} · ${((entry.value / valid) * 100).toStringAsFixed(1)}%',
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: KiteSpace.xl),
            KiteCard(
              title: 'Detalle',
              child: SizedBox(
                height: 280,
                child: KiteDataTable(
                  columns: [
                    trinaTextColumn('N.º', 'number', width: 80),
                    trinaTextColumn('Lista', 'name', width: 260),
                    trinaTextColumn('Votos', 'votes', width: 120),
                    trinaTextColumn('Porcentaje', 'share', width: 140),
                  ],
                  rows: [
                    for (final entry in ordered)
                      trinaRow({
                        'number': '${entry.key.number}',
                        'name': entry.key.name,
                        'votes': '${entry.value}',
                        'share': valid == 0
                            ? '0%'
                            : '${((entry.value / valid) * 100).toStringAsFixed(1)}%',
                      }),
                    trinaRow({
                      'number': '',
                      'name': 'En blanco',
                      'votes': '${totals.blank}',
                      'share': totals.cast == 0
                          ? '0%'
                          : '${((totals.blank / totals.cast) * 100).toStringAsFixed(1)}%',
                    }),
                    trinaRow({
                      'number': '',
                      'name': 'Nulos',
                      'votes': '${totals.nullVotes}',
                      'share': totals.cast == 0
                          ? '0%'
                          : '${((totals.nullVotes / totals.cast) * 100).toStringAsFixed(1)}%',
                    }),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
