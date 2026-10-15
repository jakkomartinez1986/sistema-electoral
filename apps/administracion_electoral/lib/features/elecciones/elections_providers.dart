import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/data/supabase_providers.dart';
import 'data/elections_repository.dart';

final electionsRepositoryProvider = Provider<ElectionsRepository>(
  (ref) => ElectionsRepository(ref.watch(supabaseClientProvider)),
);

final electionsProvider = FutureProvider<List<Election>>((ref) {
  final id = ref.watch(currentInstitutionIdProvider);
  if (id == null) return Future<List<Election>>.value(const <Election>[]);
  return ref.watch(electionsRepositoryProvider).listElections(id);
});

/// Elección activa para los módulos que operan sobre una sola elección
/// (Listas, Dispositivos, Sincronización, Resultados).
class SelectedElectionId extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? id) => state = id;
}

final selectedElectionIdProvider =
    NotifierProvider<SelectedElectionId, String?>(SelectedElectionId.new);

final electionTablesProvider = FutureProvider.family<List<VotingTable>, String>(
  (ref, electionId) =>
      ref.watch(electionsRepositoryProvider).listTables(electionId),
);

/// Estado de conciliación de una elección (pendientes, conflictos, incidencias).
final electionReconciliationProvider =
    FutureProvider.family<ElectionReconciliation, String>(
  (ref, electionId) =>
      ref.watch(electionsRepositoryProvider).reconciliation(electionId),
);
