import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/data/supabase_providers.dart';
import 'data/padron_import_repository.dart';
import 'data/students_repository.dart';

final studentsRepositoryProvider = Provider<StudentsRepository>(
  (ref) => StudentsRepository(ref.watch(supabaseClientProvider)),
);

final padronImportRepositoryProvider = Provider<PadronImportRepository>(
  (ref) => PadronImportRepository(ref.watch(supabaseClientProvider)),
);

final studentsProvider = FutureProvider<List<Student>>((ref) {
  final id = ref.watch(currentInstitutionIdProvider);
  if (id == null) return Future<List<Student>>.value(const <Student>[]);
  return ref.watch(studentsRepositoryProvider).listStudents(id);
});
