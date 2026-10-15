// Utilidades de fecha compartidas entre módulos.
//
// Las columnas `date` de PostgreSQL llegan como `yyyy-MM-dd`.

/// Interpreta una fecha `date` de PostgreSQL.
DateTime? parseDateOnly(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

/// Formatea un [DateTime] como fecha `yyyy-MM-dd`.
String dateOnly(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
