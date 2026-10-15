import 'package:supabase_flutter/supabase_flutter.dart';

import '../import/padron_import.dart';

/// Resumen devuelto por el RPC `import_election_padron`.
class PadronImportOutcome {
  const PadronImportOutcome({
    required this.total,
    required this.created,
    required this.updated,
    required this.assigned,
    required this.errorCount,
    required this.errors,
  });

  /// Filas recibidas, incluidas las que fallaron.
  final int total;
  final int created;
  final int updated;

  /// Estudiantes inscritos o reasignados en el padrón de la elección.
  final int assigned;
  final int errorCount;
  final List<PadronImportError> errors;

  factory PadronImportOutcome.fromMap(Map<String, Object?> map) =>
      PadronImportOutcome(
        total: (map['total'] as num?)?.toInt() ?? 0,
        created: (map['created'] as num?)?.toInt() ?? 0,
        updated: (map['updated'] as num?)?.toInt() ?? 0,
        assigned: (map['assigned'] as num?)?.toInt() ?? 0,
        errorCount: (map['error_count'] as num?)?.toInt() ?? 0,
        errors: <PadronImportError>[
          for (final error in (map['errors'] as List<Object?>? ?? const []))
            PadronImportError.fromMap((error! as Map).cast<String, Object?>()),
        ],
      );
}

/// Error de una fila concreta devuelto por el servidor.
class PadronImportError {
  const PadronImportError({required this.row, required this.message});

  final int row;
  final String message;

  factory PadronImportError.fromMap(Map<String, Object?> map) =>
      PadronImportError(
        row: (map['row'] as num?)?.toInt() ?? 0,
        message: '${map['message']}',
      );

  String get label => 'Línea $row: ${_humanize(message)}';
}

String _humanize(String code) => switch (code) {
  'missing_code' => 'falta el código interno',
  'missing_name' => 'faltan los nombres o los apellidos',
  'invalid_pin' => 'el PIN no es válido',
  'table_not_found' => 'la mesa indicada no existe en esta elección',
  _ => code,
};

class PadronImportRepository {
  PadronImportRepository(this._client);

  final SupabaseClient _client;

  Future<PadronImportOutcome> importPadron({
    required String electionId,
    required List<PadronImportRow> rows,
  }) async {
    final result = await _client.rpc(
      'import_election_padron',
      params: <String, Object?>{
        'p_election_id': electionId,
        'p_rows': <Map<String, Object?>>[for (final row in rows) row.toJson()],
      },
    );
    return PadronImportOutcome.fromMap((result as Map).cast<String, Object?>());
  }
}
