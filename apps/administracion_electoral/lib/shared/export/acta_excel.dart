import 'package:excel/excel.dart';

import 'acta.dart';

String _stamp(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

String _percent(int value, int total) {
  if (total <= 0) return '0.0%';
  return '${(value / total * 100).toStringAsFixed(1)}%';
}

/// Genera el acta de resultados en Excel (xlsx), sin identidad del votante.
List<int> buildActaExcel(ActaData data) {
  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet();
  final sheet = excel['Resultados'];
  if (defaultSheet != null && defaultSheet != 'Resultados') {
    excel.delete(defaultSheet);
  }

  void text(int column, int row, String value) {
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row))
        .value = TextCellValue(value);
  }

  void number(int column, int row, int value) {
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row))
        .value = IntCellValue(value);
  }

  var row = 0;
  text(0, row++, 'ACTA DE RESULTADOS');
  text(0, row++, data.institutionName);
  text(0, row++, 'Elección: ${data.electionName}');
  text(0, row++, 'Estado: ${data.statusLabel}');
  if (data.closedAt != null) {
    text(0, row++, 'Fecha de cierre: ${_stamp(data.closedAt!)}');
  }
  text(0, row++, 'Emitido: ${_stamp(data.generatedAt)}');
  row++;

  text(0, row, 'N.º');
  text(1, row, 'Lista');
  text(2, row, 'Votos');
  text(3, row, '% válidos');
  row++;
  for (final item in data.orderedByVotes) {
    number(0, row, item.number);
    text(1, row, item.name);
    number(2, row, item.votes);
    text(3, row, _percent(item.votes, data.validVotes));
    row++;
  }
  row++;

  text(0, row, 'Votos válidos');
  number(1, row, data.validVotes);
  row++;
  text(0, row, 'Votos en blanco');
  number(1, row, data.blank);
  row++;
  text(0, row, 'Votos nulos');
  number(1, row, data.nullVotes);
  row++;
  text(0, row, 'Total escrutado');
  number(1, row, data.cast);
  row++;
  if (data.participation != null) {
    text(0, row, 'Participación (registros)');
    number(1, row, data.participation!);
    row++;
  }
  if (data.issued != null) {
    text(0, row, 'Operaciones registradas');
    number(1, row, data.issued!);
    row++;
  }

  return excel.encode() ?? <int>[];
}
