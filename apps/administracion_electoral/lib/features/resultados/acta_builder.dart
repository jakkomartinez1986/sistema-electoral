import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/export/acta.dart';
import '../elecciones/data/elections_repository.dart';
import '../institucion/institution_providers.dart';
import '../listas/lists_providers.dart';
import '../sincronizacion/sync_providers.dart';
import 'data/results_repository.dart';

/// Reúne los agregados congelados de una elección para generar su acta.
///
/// Es glue de presentación: une las listas, la institución y los contadores de
/// sincronización en un objeto [ActaData] puro que luego se exporta.
Future<ActaData> buildActaData(
  WidgetRef ref, {
  required Election election,
  required ElectionTotals totals,
}) async {
  final lists = await ref.read(candidateListsProvider(election.id).future);
  final institution = await ref.read(institutionProvider.future);
  final counts = await ref.read(syncCountsProvider(election.id).future);
  final rows = <ActaListRow>[];
  for (final list in lists) {
    final votes = totals.byList[list.id];
    if (votes == null) continue;
    rows.add(ActaListRow(number: list.number, name: list.name, votes: votes));
  }
  return ActaData(
    institutionName: institution?.name ?? 'Institución educativa',
    electionName: election.name,
    statusLabel: electionStatusLabel(election.status),
    generatedAt: DateTime.now(),
    lists: rows,
    blank: totals.blank,
    nullVotes: totals.nullVotes,
    closedAt: election.closesAt,
    participation: counts.participation,
    issued: counts.issued,
  );
}
