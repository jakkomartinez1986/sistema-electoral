import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/supabase_providers.dart';
import 'data/sync_repository.dart';

final syncRepositoryProvider = Provider<SyncRepository>(
  (ref) => SyncRepository(ref.watch(supabaseClientProvider)),
);

final syncCountsProvider = FutureProvider.family<SyncCounts, String>(
  (ref, electionId) =>
      ref.watch(syncRepositoryProvider).loadCounts(electionId),
);

final participationByTableProvider =
    FutureProvider.family<Map<String?, int>, String>(
      (ref, electionId) =>
          ref.watch(syncRepositoryProvider).participationByTable(electionId),
    );

final incidentsProvider = FutureProvider.family<List<Incident>, String>(
  (ref, electionId) =>
      ref.watch(syncRepositoryProvider).listIncidents(electionId),
);
