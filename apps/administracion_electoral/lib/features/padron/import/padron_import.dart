import 'package:electoral_core/electoral_core.dart';

/// Campo reconocible de una columna del archivo de padrón.
enum PadronField {
  internalCode,
  firstName,
  lastName,
  cedula,
  tableCode,
  pin,
  birthDate,
  status,
  enabled,
}

/// Fila del padrón ya validada y normalizada, lista para enviar al servidor.
class PadronImportRow {
  const PadronImportRow({
    required this.line,
    required this.internalCode,
    required this.firstName,
    required this.lastName,
    required this.status,
    required this.enabled,
    this.cedula,
    this.tableCode,
    this.pin,
    this.birthDate,
  });

  /// Número de línea (1-based, contando el encabezado) para ubicar el origen.
  final int line;
  final String internalCode;
  final String firstName;
  final String lastName;
  final String status;
  final bool enabled;
  final String? cedula;
  final String? tableCode;
  final String? pin;

  /// Fecha en formato ISO `yyyy-MM-dd`.
  final String? birthDate;

  Map<String, Object?> toJson() => <String, Object?>{
    'internal_code': internalCode,
    'first_name': firstName,
    'last_name': lastName,
    'cedula': cedula,
    'table_code': tableCode,
    'pin': pin,
    'birth_date': birthDate,
    'status': status,
    'enabled': enabled,
  };
}

/// Problema detectado en una línea del archivo; la fila no se importa.
class PadronImportIssue {
  const PadronImportIssue(this.line, this.message);

  final int line;
  final String message;

  String get label => 'Línea $line: $message';
}

/// Resultado de leer un archivo: filas válidas e incidencias por línea.
class PadronImportBatch {
  const PadronImportBatch({required this.rows, required this.issues});

  final List<PadronImportRow> rows;
  final List<PadronImportIssue> issues;

  bool get isEmpty => rows.isEmpty && issues.isEmpty;

  bool get hasRows => rows.isNotEmpty;
}

/// Encabezados aceptados (normalizados) para cada campo.
const Map<String, PadronField> _fieldAliases = <String, PadronField>{
  'codigo': PadronField.internalCode,
  'codigo interno': PadronField.internalCode,
  'codigo estudiantil': PadronField.internalCode,
  'codigo estudiante': PadronField.internalCode,
  'codigo del estudiante': PadronField.internalCode,
  'internal code': PadronField.internalCode,
  'nombres': PadronField.firstName,
  'nombre': PadronField.firstName,
  'nombres completos': PadronField.firstName,
  'first name': PadronField.firstName,
  'apellidos': PadronField.lastName,
  'apellido': PadronField.lastName,
  'last name': PadronField.lastName,
  'cedula': PadronField.cedula,
  'ci': PadronField.cedula,
  'documento': PadronField.cedula,
  'mesa': PadronField.tableCode,
  'mesa codigo': PadronField.tableCode,
  'codigo mesa': PadronField.tableCode,
  'codigo de mesa': PadronField.tableCode,
  'tabla': PadronField.tableCode,
  'table code': PadronField.tableCode,
  'pin': PadronField.pin,
  'clave': PadronField.pin,
  'fecha de nacimiento': PadronField.birthDate,
  'fecha nacimiento': PadronField.birthDate,
  'nacimiento': PadronField.birthDate,
  'birth date': PadronField.birthDate,
  'estado': PadronField.status,
  'status': PadronField.status,
  'habilitado': PadronField.enabled,
  'habilitado para votar': PadronField.enabled,
  'enabled': PadronField.enabled,
};

const Map<String, String> _accentMap = <String, String>{
  'á': 'a',
  'à': 'a',
  'ä': 'a',
  'â': 'a',
  'ã': 'a',
  'é': 'e',
  'è': 'e',
  'ë': 'e',
  'ê': 'e',
  'í': 'i',
  'ì': 'i',
  'ï': 'i',
  'î': 'i',
  'ó': 'o',
  'ò': 'o',
  'ö': 'o',
  'ô': 'o',
  'õ': 'o',
  'ú': 'u',
  'ù': 'u',
  'ü': 'u',
  'û': 'u',
  'ñ': 'n',
  'ç': 'c',
};

/// Normaliza un texto para comparar encabezados: minúsculas, sin acentos y con
/// los separadores reducidos a espacios simples.
String normalizePadronHeader(String raw) {
  final buffer = StringBuffer();
  for (final rune in raw.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(_accentMap[ch] ?? ch);
  }
  return buffer
      .toString()
      .replaceAll(RegExp('[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

/// Lee un archivo CSV (o delimitado por `;`/tabulador) y devuelve el lote.
PadronImportBatch parsePadronCsv(String content) {
  final clean = content.startsWith('\uFEFF') ? content.substring(1) : content;
  final delimiter = _detectDelimiter(clean);
  final matrix = _splitDelimited(clean, delimiter);
  return padronBatchFromMatrix(matrix);
}

/// Construye el lote a partir de una matriz de celdas (encabezado + filas).
///
/// Es la costura común entre CSV y Excel, de modo que la validación sea idéntica
/// venga de donde venga el archivo.
PadronImportBatch padronBatchFromMatrix(List<List<String>> matrix) {
  final headerIndex = matrix.indexWhere(
    (row) => row.any((cell) => cell.trim().isNotEmpty),
  );
  if (headerIndex == -1) {
    return const PadronImportBatch(
      rows: <PadronImportRow>[],
      issues: <PadronImportIssue>[
        PadronImportIssue(1, 'El archivo está vacío.'),
      ],
    );
  }

  final indexByField = <PadronField, int>{};
  final header = matrix[headerIndex];
  for (var i = 0; i < header.length; i++) {
    final field = _fieldAliases[normalizePadronHeader(header[i])];
    if (field != null && !indexByField.containsKey(field)) {
      indexByField[field] = i;
    }
  }

  if (indexByField.isEmpty) {
    return const PadronImportBatch(
      rows: <PadronImportRow>[],
      issues: <PadronImportIssue>[
        PadronImportIssue(
          1,
          'No se reconoció ninguna columna. Se esperan encabezados como '
          '"Código", "Apellidos", "Nombres", "Cédula", "Mesa" o "PIN".',
        ),
      ],
    );
  }

  final rows = <PadronImportRow>[];
  final issues = <PadronImportIssue>[];

  for (var r = headerIndex + 1; r < matrix.length; r++) {
    final raw = matrix[r];
    if (raw.every((cell) => cell.trim().isEmpty)) continue;
    final line = r + 1;

    String value(PadronField field) {
      final index = indexByField[field];
      if (index == null || index >= raw.length) return '';
      return raw[index].trim();
    }

    final rowIssues = <String>[];

    final code = value(PadronField.internalCode);
    if (code.isEmpty) rowIssues.add('falta el código interno');

    final first = value(PadronField.firstName);
    final last = value(PadronField.lastName);
    if (first.isEmpty || last.isEmpty) {
      rowIssues.add('faltan los nombres o los apellidos');
    }

    String? cedula;
    final cedulaRaw = value(PadronField.cedula);
    if (cedulaRaw.isNotEmpty) {
      cedula = CedulaEcuador.normalize(cedulaRaw);
      if (cedula == null) rowIssues.add('la cédula "$cedulaRaw" no es válida');
    }

    String? pin;
    final pinRaw = value(PadronField.pin);
    if (pinRaw.isNotEmpty) {
      if (RegExp(r'^[0-9]{4,8}$').hasMatch(pinRaw)) {
        pin = pinRaw;
      } else {
        rowIssues.add('el PIN debe tener de 4 a 8 dígitos');
      }
    }

    String? birthDate;
    final birthRaw = value(PadronField.birthDate);
    if (birthRaw.isNotEmpty) {
      birthDate = _parseFlexibleDate(birthRaw);
      if (birthDate == null) {
        rowIssues.add('la fecha de nacimiento "$birthRaw" no es válida');
      }
    }

    final statusRaw = value(PadronField.status);
    final status = _parseStatus(statusRaw);
    if (status == null) {
      rowIssues.add('el estado "$statusRaw" no se reconoce');
    }

    if (rowIssues.isNotEmpty) {
      issues.add(PadronImportIssue(line, rowIssues.join('; ')));
      continue;
    }

    final tableCode = value(PadronField.tableCode);
    rows.add(
      PadronImportRow(
        line: line,
        internalCode: code,
        firstName: first,
        lastName: last,
        status: status!,
        enabled: _parseEnabled(value(PadronField.enabled)),
        cedula: cedula,
        tableCode: tableCode.isEmpty ? null : tableCode,
        pin: pin,
        birthDate: birthDate,
      ),
    );
  }

  return PadronImportBatch(rows: rows, issues: issues);
}

String _detectDelimiter(String content) {
  final lines = content.split(RegExp(r'\r?\n'));
  final header = lines.firstWhere(
    (line) => line.trim().isNotEmpty,
    orElse: () => '',
  );
  var best = ',';
  var bestCount = 0;
  for (final delimiter in const [',', ';', '\t']) {
    final count = delimiter.allMatches(header).length;
    if (count > bestCount) {
      bestCount = count;
      best = delimiter;
    }
  }
  return best;
}

List<List<String>> _splitDelimited(String content, String delimiter) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  final delimiterCode = delimiter.codeUnitAt(0);

  void endField() {
    row.add(field.toString());
    field.clear();
  }

  void endRow() {
    endField();
    rows.add(row);
    row = <String>[];
  }

  for (var i = 0; i < content.length; i++) {
    final code = content.codeUnitAt(i);
    if (inQuotes) {
      if (code == 0x22) {
        if (i + 1 < content.length && content.codeUnitAt(i + 1) == 0x22) {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(content[i]);
      }
    } else if (code == 0x22) {
      inQuotes = true;
    } else if (code == delimiterCode) {
      endField();
    } else if (code == 0x0A) {
      endRow();
    } else if (code == 0x0D) {
      // Se ignora: el salto se maneja con el \n siguiente.
    } else {
      field.write(content[i]);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}

String? _parseStatus(String raw) {
  if (raw.isEmpty) return 'active';
  return switch (normalizePadronHeader(raw)) {
    'activo' || 'active' => 'active',
    'inactivo' || 'inactive' => 'inactive',
    'graduado' || 'graduated' => 'graduated',
    _ => null,
  };
}

bool _parseEnabled(String raw) {
  const disabled = <String>{
    'no',
    'n',
    'false',
    '0',
    'deshabilitado',
    'deshabilitada',
    'inhabilitado',
    'inhabilitada',
  };
  return !disabled.contains(normalizePadronHeader(raw));
}

String? _parseFlexibleDate(String raw) {
  final value = raw.trim();
  final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(value);
  if (iso != null) {
    return _isoDate(
      int.parse(iso.group(1)!),
      int.parse(iso.group(2)!),
      int.parse(iso.group(3)!),
    );
  }
  final dmy = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$').firstMatch(value);
  if (dmy != null) {
    return _isoDate(
      int.parse(dmy.group(3)!),
      int.parse(dmy.group(2)!),
      int.parse(dmy.group(1)!),
    );
  }
  return null;
}

String? _isoDate(int year, int month, int day) {
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  final mm = month.toString().padLeft(2, '0');
  final dd = day.toString().padLeft(2, '0');
  return '$year-$mm-$dd';
}
