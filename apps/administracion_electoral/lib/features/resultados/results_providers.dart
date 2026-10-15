import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/supabase_providers.dart';
import 'data/results_repository.dart';

final resultsRepositoryProvider = Provider<ResultsRepository>(
  (ref) => ResultsRepository(ref.watch(supabaseClientProvider)),
);

final electionTotalsProvider = FutureProvider.family<ElectionTotals, String>(
  (ref, electionId) =>
      ref.watch(resultsRepositoryProvider).loadTotals(electionId),
);
