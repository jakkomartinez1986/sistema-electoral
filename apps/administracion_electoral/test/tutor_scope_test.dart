import 'package:administracion_electoral/features/tutor/data/tutor_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TutorScope.fromMap', () {
    test('parses courses and students from the RPC payload', () {
      final scope = TutorScope.fromMap({
        'courses': [
          {
            'course_id': 'c-1',
            'display_name': '10mo A',
            'grade': '10',
            'parallel': 'A',
            'academic_year_id': 'y-1',
          },
        ],
        'students': [
          {
            'election_id': 'e-1',
            'election_name': 'Consejo 2025',
            'course_id': 'c-1',
            'voting_table_code': 'M1',
            'internal_code': 'A-001',
            'first_name': 'Ana',
            'last_name': 'Demo',
            'cedula': '1710034065',
            'status': 'active',
            'enabled': true,
          },
        ],
      });

      expect(scope.courses, hasLength(1));
      expect(scope.courses.first.id, 'c-1');
      expect(scope.courses.first.displayName, '10mo A');
      expect(scope.students, hasLength(1));
      final student = scope.students.first;
      expect(student.fullName, 'Demo, Ana');
      expect(student.internalCode, 'A-001');
      expect(student.votingTableCode, 'M1');
      expect(student.enabled, isTrue);
    });

    test('studentsOf filters by course', () {
      final scope = TutorScope.fromMap({
        'courses': const [],
        'students': [
          {'course_id': 'c-1', 'internal_code': 'A', 'first_name': 'Ana',
            'last_name': 'Doe', 'election_id': 'e', 'status': 'active',
            'enabled': true},
          {'course_id': 'c-2', 'internal_code': 'B', 'first_name': 'Luis',
            'last_name': 'Doe', 'election_id': 'e', 'status': 'active',
            'enabled': true},
        ],
      });
      expect(scope.studentsOf('c-1'), hasLength(1));
      expect(scope.studentsOf('c-1').first.internalCode, 'A');
      expect(scope.studentsOf('c-2').first.internalCode, 'B');
      expect(scope.studentsOf('missing'), isEmpty);
    });

    test('tolerates missing fields and null cedula/table', () {
      final scope = TutorScope.fromMap({
        'courses': [
          {'course_id': 'c-1', 'display_name': 'X'},
        ],
        'students': [
          {
            'election_id': 'e',
            'course_id': 'c-1',
            'internal_code': 'A',
            'first_name': 'Ana',
            'last_name': 'Doe',
            'cedula': null,
            'voting_table_code': null,
            'enabled': false,
          },
        ],
      });
      expect(scope.courses.first.grade, '');
      expect(scope.students.first.cedula, isNull);
      expect(scope.students.first.electionName, '—');
      expect(scope.students.first.status, 'active');
      expect(scope.students.first.enabled, isFalse);
    });

    test('empty payload yields an empty scope', () {
      final scope = TutorScope.fromMap(const {});
      expect(scope.courses, isEmpty);
      expect(scope.students, isEmpty);
      expect(TutorScope.empty.courses, isEmpty);
    });
  });
}
