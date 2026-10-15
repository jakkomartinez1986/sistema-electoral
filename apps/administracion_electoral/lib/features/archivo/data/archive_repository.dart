import 'package:supabase_flutter/supabase_flutter.dart';

/// Entrada del registro de auditoría (nunca contiene votos ni contraseñas).
class AuditEntry {
  const AuditEntry({
    required this.action,
    this.targetType,
    this.createdAt,
  });

  final String action;
  final String? targetType;
  final DateTime? createdAt;

  factory AuditEntry.fromMap(Map<String, Object?> map) => AuditEntry(
    action: map['action'] as String,
    targetType: map['target_type'] as String?,
    createdAt: _parse(map['created_at']),
  );
}

DateTime? _parse(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

class ArchiveRepository {
  ArchiveRepository(this._client);

  final SupabaseClient _client;

  Future<List<AuditEntry>> listAuditLogs(String institutionId) async {
    final rows = await _client
        .from('audit_logs')
        .select('action, target_type, created_at')
        .eq('institution_id', institutionId)
        .order('created_at', ascending: false)
        .limit(200);
    return rows.map(AuditEntry.fromMap).toList();
  }
}
