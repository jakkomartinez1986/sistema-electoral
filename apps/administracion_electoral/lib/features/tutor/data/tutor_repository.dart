import 'package:supabase_flutter/supabase_flutter.dart';

/// Curso dentro del ámbito de un tutor.
class TutorCourse {
  const TutorCourse({
    required this.id,
    required this.displayName,
    required this.grade,
    required this.parallel,
    required this.academicYearId,
  });

  final String id;
  final String displayName;
  final String grade;
  final String parallel;
  final String academicYearId;

  factory TutorCourse.fromMap(Map<String, Object?> map) => TutorCourse(
    id: map['course_id'] as String,
    displayName: map['display_name'] as String,
    grade: (map['grade'] as String?) ?? '',
    parallel: (map['parallel'] as String?) ?? '',
    academicYearId: (map['academic_year_id'] as String?) ?? '',
  );
}

/// Estudiante visto por un tutor: acotado a los cursos que tiene asignados.
class TutorStudent {
  const TutorStudent({
    required this.electionId,
    required this.electionName,
    required this.courseId,
    required this.internalCode,
    required this.firstName,
    required this.lastName,
    required this.status,
    required this.enabled,
    this.votingTableCode,
    this.cedula,
  });

  final String electionId;
  final String electionName;
  final String courseId;
  final String? votingTableCode;
  final String internalCode;
  final String firstName;
  final String lastName;
  final String? cedula;
  final String status;
  final bool enabled;

  String get fullName => '$lastName, $firstName';

  factory TutorStudent.fromMap(Map<String, Object?> map) => TutorStudent(
    electionId: map['election_id'] as String,
    electionName: (map['election_name'] as String?) ?? '—',
    courseId: map['course_id'] as String,
    votingTableCode: map['voting_table_code'] as String?,
    internalCode: map['internal_code'] as String,
    firstName: map['first_name'] as String,
    lastName: map['last_name'] as String,
    cedula: map['cedula'] as String?,
    status: (map['status'] as String?) ?? 'active',
    enabled: (map['enabled'] as bool?) ?? true,
  );
}

/// Ámbito completo de un tutor: sus cursos y los estudiantes de esos cursos.
class TutorScope {
  const TutorScope({required this.courses, required this.students});

  final List<TutorCourse> courses;
  final List<TutorStudent> students;

  /// Estudiantes de un curso concreto (según su `courseId`).
  List<TutorStudent> studentsOf(String courseId) => [
    for (final s in students)
      if (s.courseId == courseId) s,
  ];

  factory TutorScope.fromMap(Map<String, Object?> map) {
    final courses = (map['courses'] as List?) ?? const <Object?>[];
    final students = (map['students'] as List?) ?? const <Object?>[];
    return TutorScope(
      courses: [
        for (final c in courses)
          TutorCourse.fromMap((c as Map).cast<String, Object?>()),
      ],
      students: [
        for (final s in students)
          TutorStudent.fromMap((s as Map).cast<String, Object?>()),
      ],
    );
  }

  static const empty = TutorScope(courses: [], students: []);
}

/// Consulta del ámbito del tutor a través del RPC `get_tutor_scope`.
///
/// El backend acota los datos por `auth.uid()`, así que el tutor solo recibe sus
/// cursos y los estudiantes de esos cursos aunque no tenga permiso de lectura
/// directo sobre `election_voters`/`elections`.
class TutorRepository {
  TutorRepository(this._client);

  final SupabaseClient _client;

  Future<TutorScope> loadScope() async {
    final data = await _client.rpc('get_tutor_scope');
    if (data is! Map) return TutorScope.empty;
    return TutorScope.fromMap(data.cast<String, Object?>());
  }
}
