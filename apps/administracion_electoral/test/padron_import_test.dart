import 'package:administracion_electoral/features/padron/import/padron_import.dart';
import 'package:administracion_electoral/features/padron/import/padron_xlsx.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Padron CSV import', () {
    test('parses with header and detects delimiters', () {
      final csv =
          'Código,Apellidos,Nombres,Cédula,Mesa,PIN,Fecha de nacimiento,Estado,Habilitado\n'
          'A-001,Doe,John,1710034065,M1,1234,2010-05-01,Activo,Si\n'
          'A-002,Smith,Jane,,M1,,2010-06-02,Inactivo,No';
      final batch = parsePadronCsv(csv);
      expect(batch.rows.length, 2);
      expect(batch.issues, isEmpty);

      final first = batch.rows[0];
      expect(first.internalCode, 'A-001');
      expect(first.lastName, 'Doe');
      expect(first.firstName, 'John');
      expect(first.cedula, '1710034065');
      expect(first.tableCode, 'M1');
      expect(first.pin, '1234');
      expect(first.birthDate, '2010-05-01');
      expect(first.status, 'active');
      expect(first.enabled, true);

      final second = batch.rows[1];
      expect(second.status, 'inactive');
      expect(second.enabled, false);
      expect(second.pin, null);
    });

    test('accepts semicolon delimiter and collapses BOM', () {
      final csv = '\uFEFFCódigo;Apellidos;Nombres;Mesa\nA-001;Doe;John;M1';
      final batch = parsePadronCsv(csv);
      expect(batch.rows.length, 1);
      expect(batch.rows[0].internalCode, 'A-001');
    });

    test('quotes and embedded commas', () {
      final csv =
          'Código,Apellidos,Nombres,Mesa\n'
          '"A-001","Doe, Jr.","John","M1, A"';
      final batch = parsePadronCsv(csv);
      expect(batch.rows.length, 1);
      expect(batch.rows[0].lastName, 'Doe, Jr.');
      expect(batch.rows[0].tableCode, 'M1, A');
    });

    test('flags missing data and validates pin/cedula', () {
      final csv =
          'Código,Apellidos,Nombres,Pin,Cédula\n'
          ',Doe,John,123,1234567890\n'
          'A-002,Doe,Jane,12,1111111111';
      final batch = parsePadronCsv(csv);
      expect(batch.rows, isEmpty);
      expect(batch.issues.length, 2);
      expect(batch.issues[0].label, contains('falta el código interno'));
      expect(batch.issues[1].label, contains('PIN'));
    });

    test('handles dd/mm/yyyy and ISO date', () {
      final csv =
          'Código,Apellidos,Nombres,Fecha de nacimiento\n'
          'A-001,Doe,John,01/05/2010\n'
          'A-002,Doe,Jane,2010-06-15';
      final batch = parsePadronCsv(csv);
      expect(batch.rows.length, 2);
      expect(batch.rows[0].birthDate, '2010-05-01');
      expect(batch.rows[1].birthDate, '2010-06-15');
    });

    test('skips empty lines and finds header even if prefixed', () {
      final csv = '\n\nCódigo,Apellidos,Nombres\nA-001,Doe,John\n\n';
      final batch = parsePadronCsv(csv);
      expect(batch.rows.length, 1);
    });

    test('rejects unrecognized headers', () {
      final csv = 'Columna A,Columna B,Columna C\n1,Doe,John';
      final batch = parsePadronCsv(csv);
      expect(batch.rows, isEmpty);
      expect(batch.issues.length, 1);
      expect(
        batch.issues[0].message,
        contains('No se reconoció ninguna columna'),
      );
    });
  });

  group('Padron XLSX import', () {
    test('round trip via Excel package', () {
      final excel = Excel.createExcel();
      final sheet = excel.tables[excel.tables.keys.first]!;
      sheet.appendRow([
        TextCellValue('Código'),
        TextCellValue('Apellidos'),
        TextCellValue('Nombres'),
        TextCellValue('Cédula'),
        TextCellValue('Mesa'),
        TextCellValue('Estado'),
      ]);
      sheet.appendRow([
        TextCellValue('X-001'),
        TextCellValue('Test'),
        TextCellValue('Uno'),
        TextCellValue('1710034065'),
        TextCellValue('M99'),
        TextCellValue('Activo'),
      ]);
      final bytes = excel.encode();
      expect(bytes, isNotEmpty);

      final batch = parsePadronXlsx(bytes!);
      expect(batch.rows.length, 1);
      expect(batch.rows[0].internalCode, 'X-001');
      expect(batch.rows[0].cedula, '1710034065');
      expect(batch.rows[0].status, 'active');
      expect(batch.rows[0].enabled, true);
    });

    test('handles empty xlsx-like (no sheets)', () {
      final batch = parsePadronXlsx(<int>[]);
      expect(batch.rows, isEmpty);
      expect(batch.issues.length, 1);
    });
  });

  group('PadronImportRow toJson', () {
    test('serializes to expected fields', () {
      final row = const PadronImportRow(
        line: 2,
        internalCode: 'C-001',
        firstName: 'Ana',
        lastName: 'Demo',
        status: 'active',
        enabled: true,
        cedula: '1710034065',
        tableCode: 'M1',
        pin: '1234',
        birthDate: '2010-01-01',
      );
      final map = row.toJson();
      expect(map['internal_code'], 'C-001');
      expect(map['first_name'], 'Ana');
      expect(map['last_name'], 'Demo');
      expect(map['cedula'], '1710034065');
      expect(map['table_code'], 'M1');
      expect(map['pin'], '1234');
      expect(map['birth_date'], '2010-01-01');
      expect(map['status'], 'active');
      expect(map['enabled'], true);
    });
  });
}
