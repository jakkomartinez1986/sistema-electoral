import 'package:administracion_electoral/shared/export/acta.dart';
import 'package:administracion_electoral/shared/export/acta_excel.dart';
import 'package:administracion_electoral/shared/export/acta_file_name.dart';
import 'package:administracion_electoral/shared/export/acta_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

ActaData _sample() => ActaData(
  institutionName: 'Unidad Educativa de Pruebas',
  electionName: 'Elección del personero 2025',
  statusLabel: 'Cerrada',
  generatedAt: DateTime(2025, 10, 14, 9, 30),
  closedAt: DateTime(2025, 10, 14, 18, 0),
  lists: const [
    ActaListRow(number: 1, name: 'Lista Azul', votes: 10),
    ActaListRow(number: 2, name: 'Lista Roja', votes: 10),
    ActaListRow(number: 3, name: 'Lista Verde', votes: 25),
  ],
  blank: 3,
  nullVotes: 2,
  participation: 50,
  issued: 51,
);

void main() {
  group('ActaData', () {
    test('suma votos válidos, en blanco y nulos', () {
      final data = _sample();
      expect(data.validVotes, 45);
      expect(data.cast, 50);
    });

    test('ordena por votos y desempata por número', () {
      final ordered = _sample().orderedByVotes;
      expect(ordered.map((r) => r.number).toList(), [3, 1, 2]);
    });
  });

  group('actaFileName', () {
    test('quita acentos y espacios del nombre de la elección', () {
      expect(
        actaFileName(_sample(), 'pdf'),
        'acta-eleccion-del-personero-2025.pdf',
      );
    });

    test('usa un nombre genérico si no queda texto', () {
      final data = ActaData(
        institutionName: 'x',
        electionName: '###',
        statusLabel: 'Cerrada',
        generatedAt: DateTime(2025),
        lists: const [],
        blank: 0,
        nullVotes: 0,
      );
      expect(actaFileName(data, 'xlsx'), 'acta.xlsx');
    });
  });

  group('buildActaExcel', () {
    test('produce un archivo xlsx (contenedor ZIP) no vacío', () {
      final bytes = buildActaExcel(_sample());
      expect(bytes, isNotEmpty);
      expect(bytes.take(2).toList(), [0x50, 0x4B]);
    });
  });

  group('buildActaPdf', () {
    test('produce un PDF válido con el encabezado esperado', () async {
      final bytes = await buildActaPdf(_sample());
      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });
}
