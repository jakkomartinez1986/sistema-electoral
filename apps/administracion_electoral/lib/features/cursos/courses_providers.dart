import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/data/supabase_providers.dart';
import 'data/courses_repository.dart';

final coursesRepositoryProvider = Provider<CoursesRepository>(
  (ref) => CoursesRepository(ref.watch(supabaseClientProvider)),
);

final coursesProvider = FutureProvider.family<List<Course>, String>(
  (ref, academicYearId) =>
      ref.watch(coursesRepositoryProvider).listCourses(academicYearId),
);

final tutorsProvider = FutureProvider<List<StaffOption>>((ref) {
  final id = ref.watch(currentInstitutionIdProvider);
  if (id == null) return Future<List<StaffOption>>.value(const <StaffOption>[]);
  return ref.watch(coursesRepositoryProvider).listTutors(id);
});

final votingTablesProvider =
    FutureProvider.family<List<VotingTableRow>, String>(
      (ref, academicYearId) => ref
          .watch(coursesRepositoryProvider)
          .listVotingTablesForYear(academicYearId),
    );
