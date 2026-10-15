import 'package:excel/excel.dart';

import 'padron_import.dart';

/// Lee un archivo `.xlsx` y devuelve el lote del padrón.
///
/// Solo se admite la primera hoja del libro. La validación de las filas es la
/// misma que para CSV ([padronBatchFromMatrix]).
PadronImportBatch parsePadronXlsx(List<int> bytes) {
  final Excel excel;
  try {
    excel = Excel.decodeBytes(bytes);
  } catch (_) {
    return const PadronImportBatch(
      rows: <PadronImportRow>[],
      issues: <PadronImportIssue>[
        PadronImportIssue(1, 'No se pudo leer el archivo Excel (.xlsx).'),
      ],
    );
  }

  if (excel.tables.isEmpty) {
    return const PadronImportBatch(
      rows: <PadronImportRow>[],
      issues: <PadronImportIssue>[
        PadronImportIssue(1, 'El libro no tiene hojas.'),
      ],
    );
  }

  final sheet = excel.tables.values.first;
  final matrix = <List<String>>[
    for (final row in sheet.rows)
      <String>[for (final cell in row) cellText(cell)],
  ];
  return padronBatchFromMatrix(matrix);
}

/// Convierte una celda de Excel a texto plano.
String cellText(Data? cell) {
  final value = cell?.value;
  return switch (value) {
    null => '',
    TextCellValue v => v.value.text ?? '',
    DateCellValue v => v.asDateTimeUtc().toIso8601String().substring(0, 10),
    DateTimeCellValue v => v.asDateTimeUtc().toIso8601String().substring(0, 10),
    _ => value.toString().trim(),
  };
}
