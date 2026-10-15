import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/supabase_providers.dart';
import 'data/lists_repository.dart';

final listsRepositoryProvider = Provider<ListsRepository>(
  (ref) => ListsRepository(ref.watch(supabaseClientProvider)),
);

final candidateListsProvider =
    FutureProvider.family<List<CandidateList>, String>(
      (ref, electionId) =>
          ref.watch(listsRepositoryProvider).listLists(electionId),
    );

final candidatesProvider = FutureProvider.family<List<CandidateItem>, String>(
  (ref, listId) => ref.watch(listsRepositoryProvider).listCandidates(listId),
);