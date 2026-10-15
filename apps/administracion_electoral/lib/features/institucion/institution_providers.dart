import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/data/supabase_providers.dart';
import 'data/institution_repository.dart';

final institutionRepositoryProvider = Provider<InstitutionRepository>(
  (ref) => InstitutionRepository(ref.watch(supabaseClientProvider)),
);

final institutionProvider = FutureProvider<Institution?>((ref) {
  final id = ref.watch(currentInstitutionIdProvider);
  if (id == null) return Future<Institution?>.value(null);
  return ref.watch(institutionRepositoryProvider).fetchInstitution(id);
});

final academicYearsProvider = FutureProvider<List<AcademicYear>>((ref) {
  final id = ref.watch(currentInstitutionIdProvider);
  if (id == null) return Future<List<AcademicYear>>.value(const <AcademicYear>[]);
  return ref.watch(institutionRepositoryProvider).listAcademicYears(id);
});

/// Zonas horarias IANA ofrecidas en el formulario institucional.
const List<String> kTimeZones = <String>[
  'America/Guayaquil',
  'America/Bogota',
  'America/Lima',
  'America/Mexico_City',
  'America/Santiago',
  'America/Argentina/Buenos_Aires',
  'America/Caracas',
  'Europe/Madrid',
  'UTC',
];
