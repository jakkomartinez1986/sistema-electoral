import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/util/dates.dart';

/// Estados posibles de un estudiante (enum `student_status`).
const List<String> kStudentStatuses = <String>[
  'active',
  'inactive',
  'graduated',
];

String studentStatusLabel(String status) => switch (status) {
  'active' => 'Activo',
  'inactive' => 'Inactivo',
  'graduated' => 'Graduado',
  _ => status,
};

/// Estudiante: datos personales mínimos.
class Student {
  const Student({
    required this.id,
    required this.institutionId,
    required this.internalCode,
    required this.firstName,
    required this.lastName,
    required this.status,
    required this.enabled,
    this.cedula,
    this.birthDate,
  });

  final String id;
  final String institutionId;
  final String internalCode;
  final String? cedula;
  final String firstName;
  final String lastName;
  final DateTime? birthDate;
  final String status;
  final bool enabled;

  String get fullName => '$lastName $firstName';

  factory Student.fromMap(Map<String, Object?> map) => Student(
    id: map['id'] as String,
    institutionId: map['institution_id'] as String,
    internalCode: map['internal_code'] as String,
    cedula: map['cedula'] as String?,
    firstName: map['first_name'] as String,
    lastName: map['last_name'] as String,
    birthDate: parseDateOnly(map['birth_date']),
    status: map['status'] as String,
    enabled: map['enabled'] as bool,
  );
}

class StudentsRepository {
  StudentsRepository(this._client);

  final SupabaseClient _client;

  Future<List<Student>> listStudents(String institutionId) async {
    final rows = await _client
        .from('students')
        .select(
          'id, institution_id, internal_code, cedula, first_name, last_name, '
          'birth_date, status, enabled',
        )
        .eq('institution_id', institutionId)
        .order('last_name')
        .order('first_name');
    return rows.map(Student.fromMap).toList();
  }

  Future<void> createStudent({
    required String institutionId,
    required String internalCode,
    required String firstName,
    required String lastName,
    String? cedula,
    DateTime? birthDate,
    required String status,
    bool enabled = true,
  }) async {
    await _client.from('students').insert({
      'institution_id': institutionId,
      'internal_code': internalCode,
      'first_name': firstName,
      'last_name': lastName,
      'cedula': _blankToNull(cedula),
      'birth_date': birthDate == null ? null : dateOnly(birthDate),
      'status': status,
      'enabled': enabled,
    });
  }

  Future<void> updateStudent(
    String id, {
    required String internalCode,
    required String firstName,
    required String lastName,
    String? cedula,
    DateTime? birthDate,
    required String status,
    required bool enabled,
  }) async {
    await _client
        .from('students')
        .update({
          'internal_code': internalCode,
          'first_name': firstName,
          'last_name': lastName,
          'cedula': _blankToNull(cedula),
          'birth_date': birthDate == null ? null : dateOnly(birthDate),
          'status': status,
          'enabled': enabled,
        })
        .eq('id', id);
  }

  Future<void> deleteStudent(String id) async {
    await _client.from('students').delete().eq('id', id);
  }

  /// Indica si el estudiante ya tiene un PIN de votación definido.
  ///
  /// No trae el hash: solo comprueba si existe, para no exponer el valor.
  Future<bool> hasPin(String studentId) async {
    final row = await _client
        .from('students')
        .select('id')
        .eq('id', studentId)
        .not('access_pin_hash', 'is', null)
        .maybeSingle();
    return row != null;
  }

  /// Define el PIN de votación (4 a 8 dígitos). Se guarda como hash.
  Future<void> setStudentPin(String studentId, String pin) async {
    await _client.rpc(
      'set_student_pin',
      params: {'p_student_id': studentId, 'p_pin': pin},
    );
  }

  /// Quita el PIN de votación del estudiante.
  Future<void> clearStudentPin(String studentId) async {
    await _client.rpc(
      'set_student_pin',
      params: {'p_student_id': studentId, 'p_pin': ''},
    );
  }

  static String? _blankToNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
