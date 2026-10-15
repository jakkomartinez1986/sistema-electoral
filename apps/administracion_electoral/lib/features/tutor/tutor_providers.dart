import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/supabase_providers.dart';
import 'data/tutor_repository.dart';

final tutorRepositoryProvider = Provider<TutorRepository>(
  (ref) => TutorRepository(ref.watch(supabaseClientProvider)),
);

/// Ámbito del tutor autenticado (cursos y estudiantes). Se refresca al
/// invalidar el proveedor.
final tutorScopeProvider = FutureProvider<TutorScope>(
  (ref) => ref.watch(tutorRepositoryProvider).loadScope(),
);
