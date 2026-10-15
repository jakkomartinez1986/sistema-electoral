import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/util/dates.dart';

/// Institución: nombre y zona horaria institucional.
class Institution {
  const Institution({
    required this.id,
    required this.name,
    required this.timeZone,
    this.logoPath,
  });

  final String id;
  final String name;
  final String timeZone;
  final String? logoPath;

  factory Institution.fromMap(Map<String, Object?> map) => Institution(
    id: map['id'] as String,
    name: map['name'] as String,
    timeZone: map['time_zone'] as String,
    logoPath: map['logo_path'] as String?,
  );
}

/// Año lectivo / período.
class AcademicYear {
  const AcademicYear({
    required this.id,
    required this.institutionId,
    required this.name,
    this.startsOn,
    this.endsOn,
  });

  final String id;
  final String institutionId;
  final String name;
  final DateTime? startsOn;
  final DateTime? endsOn;

  factory AcademicYear.fromMap(Map<String, Object?> map) => AcademicYear(
    id: map['id'] as String,
    institutionId: map['institution_id'] as String,
    name: map['name'] as String,
    startsOn: parseDateOnly(map['starts_on']),
    endsOn: parseDateOnly(map['ends_on']),
  );
}

/// Acceso a `institutions` y `academic_years`.
class InstitutionRepository {
  InstitutionRepository(this._client);

  final SupabaseClient _client;

  Future<Institution?> fetchInstitution(String institutionId) async {
    final row = await _client
        .from('institutions')
        .select('id, name, time_zone, logo_path')
        .eq('id', institutionId)
        .maybeSingle();
    return row == null ? null : Institution.fromMap(row);
  }

  Future<void> updateInstitution(
    String id, {
    required String name,
    required String timeZone,
  }) async {
    await _client.from('institutions').update({
      'name': name,
      'time_zone': timeZone,
    }).eq('id', id);
  }

  Future<List<AcademicYear>> listAcademicYears(String institutionId) async {
    final rows = await _client
        .from('academic_years')
        .select('id, institution_id, name, starts_on, ends_on')
        .eq('institution_id', institutionId)
        .order('name');
    return rows.map(AcademicYear.fromMap).toList();
  }

  Future<void> createAcademicYear({
    required String institutionId,
    required String name,
    DateTime? startsOn,
    DateTime? endsOn,
  }) async {
    await _client.from('academic_years').insert({
      'institution_id': institutionId,
      'name': name,
      'starts_on': startsOn == null ? null : dateOnly(startsOn),
      'ends_on': endsOn == null ? null : dateOnly(endsOn),
    });
  }

  Future<void> updateAcademicYear(
    String id, {
    required String name,
    DateTime? startsOn,
    DateTime? endsOn,
  }) async {
    await _client.from('academic_years').update({
      'name': name,
      'starts_on': startsOn == null ? null : dateOnly(startsOn),
      'ends_on': endsOn == null ? null : dateOnly(endsOn),
    }).eq('id', id);
  }

  Future<void> deleteAcademicYear(String id) async {
    await _client.from('academic_years').delete().eq('id', id);
  }
}
