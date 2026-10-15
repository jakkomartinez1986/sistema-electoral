import 'package:supabase_flutter/supabase_flutter.dart';

/// Grado/curso y paralelo dentro de un año lectivo.
class Course {
  const Course({
    required this.id,
    required this.academicYearId,
    required this.grade,
    required this.parallel,
    required this.displayName,
    this.tutorProfileId,
  });

  final String id;
  final String academicYearId;
  final String grade;
  final String parallel;
  final String displayName;
  final String? tutorProfileId;

  factory Course.fromMap(Map<String, Object?> map) => Course(
    id: map['id'] as String,
    academicYearId: map['academic_year_id'] as String,
    grade: map['grade'] as String,
    parallel: map['parallel'] as String,
    displayName: map['display_name'] as String,
    tutorProfileId: map['tutor_profile_id'] as String?,
  );
}

/// Personal que puede asignarse como tutor de un curso.
class StaffOption {
  const StaffOption({required this.id, required this.fullName});

  final String id;
  final String fullName;

  factory StaffOption.fromMap(Map<String, Object?> map) => StaffOption(
    id: map['id'] as String,
    fullName: map['full_name'] as String,
  );
}

/// Mesa/grupo de votación (pertenece a una elección).
class VotingTableRow {
  const VotingTableRow({
    required this.id,
    required this.code,
    required this.name,
    required this.electionName,
    this.capacity,
    this.courseId,
  });

  final String id;
  final String code;
  final String? name;
  final String electionName;
  final int? capacity;
  final String? courseId;

  factory VotingTableRow.fromMap(Map<String, Object?> map) {
    final election = map['elections'] as Map<String, Object?>?;
    return VotingTableRow(
      id: map['id'] as String,
      code: map['code'] as String,
      name: map['name'] as String?,
      electionName: (election?['name'] as String?) ?? '—',
      capacity: map['capacity'] as int?,
      courseId: map['course_id'] as String?,
    );
  }
}

class CoursesRepository {
  CoursesRepository(this._client);

  final SupabaseClient _client;

  Future<List<Course>> listCourses(String academicYearId) async {
    final rows = await _client
        .from('courses')
        .select(
          'id, academic_year_id, grade, parallel, display_name, tutor_profile_id',
        )
        .eq('academic_year_id', academicYearId)
        .order('grade')
        .order('parallel');
    return rows.map(Course.fromMap).toList();
  }

  Future<void> createCourse({
    required String academicYearId,
    required String grade,
    required String parallel,
    required String displayName,
    String? tutorProfileId,
  }) async {
    await _client.from('courses').insert({
      'academic_year_id': academicYearId,
      'grade': grade,
      'parallel': parallel,
      'display_name': displayName,
      'tutor_profile_id': tutorProfileId,
    });
  }

  Future<void> updateCourse(
    String id, {
    required String grade,
    required String parallel,
    required String displayName,
    String? tutorProfileId,
  }) async {
    await _client.from('courses').update({
      'grade': grade,
      'parallel': parallel,
      'display_name': displayName,
      'tutor_profile_id': tutorProfileId,
    }).eq('id', id);
  }

  Future<void> deleteCourse(String id) async {
    await _client.from('courses').delete().eq('id', id);
  }

  Future<List<StaffOption>> listTutors(String institutionId) async {
    final rows = await _client
        .from('user_profiles')
        .select('id, full_name')
        .eq('institution_id', institutionId)
        .order('full_name');
    return rows.map(StaffOption.fromMap).toList();
  }

  Future<List<VotingTableRow>> listVotingTablesForYear(
    String academicYearId,
  ) async {
    final rows = await _client
        .from('voting_tables')
        .select(
          'id, code, name, capacity, course_id, '
          'elections!inner(name, academic_year_id)',
        )
        .eq('elections.academic_year_id', academicYearId)
        .order('code');
    return rows.map(VotingTableRow.fromMap).toList();
  }
}
