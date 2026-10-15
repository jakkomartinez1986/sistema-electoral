import 'package:kite_ui/kite_ui.dart';

/// Columna de texto de solo lectura para [KiteDataTable].
///
/// Todas las tablas de administración son de lectura: la edición se hace en un
/// panel lateral, no en la celda. Así se evita que un doble clic deje una
/// edición local sin persistir.
TrinaColumn trinaTextColumn(
  String title,
  String field, {
  double width = 160,
  TrinaColumnTextAlign align = TrinaColumnTextAlign.left,
}) => TrinaColumn(
  title: title,
  field: field,
  type: TrinaColumnType.text(),
  readOnly: true,
  width: width,
  textAlign: align,
);

/// Fila a partir de un mapa `campo → texto`.
TrinaRow<dynamic> trinaRow(Map<String, String> values) => TrinaRow(
  cells: {
    for (final entry in values.entries) entry.key: TrinaCell(value: entry.value),
  },
);

/// Convierte un valor de base de datos a texto para una celda.
String cellText(Object? value) => value == null ? '—' : value.toString();
