import 'package:supabase_flutter/supabase_flutter.dart';

const List<String> kIncidentStatuses = <String>[
  'open',
  'reviewing',
  'resolved',
  'dismissed',
];

String incidentStatusLabel(String status) => switch (status) {
  'open' => 'Abierta',
  'reviewing' => 'En revisión',
  'resolved' => 'Resuelta',
  'dismissed' => 'Descartada',
  _ => status,
};

/// Contadores de conciliación de una elección (sin identificar votos).
class SyncCounts {
  const SyncCounts({
    required this.accepted,
    required this.pending,
    required this.rejected,
    required this.conflict,
    required this.participation,
  });

  final int accepted;
  final int pending;
  final int rejected;
  final int conflict;
  final int participation;

  int get issued => accepted + pending + rejected + conflict;

  static const SyncCounts empty = SyncCounts(
    accepted: 0,
    pending: 0,
    rejected: 0,
    conflict: 0,
    participation: 0,
  );
}

/// Incidencia o conflicto de conciliación.
class Incident {
  const Incident({
    required this.id,
    required this.kind,
    required this.status,
    this.description,
    this.resolution,
    this.createdAt,
  });

  final String id;
  final String kind;
  final String status;
  final String? description;
  final String? resolution;
  final DateTime? createdAt;

  factory Incident.fromMap(Map<String, Object?> map) => Incident(
    id: map['id'] as String,
    kind: map['kind'] as String,
    status: map['status'] as String,
    description: map['description'] as String?,
    resolution: map['resolution'] as String?,
    createdAt: _parse(map['created_at']),
  );
}

/// Participación agregada por curso/mesa.
class ParticipationByTable {
  const ParticipationByTable({required this.tableId, required this.count});

  final String? tableId;
  final int count;
}

DateTime? _parse(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

class SyncRepository {
  SyncRepository(this._client);

  final SupabaseClient _client;

  Future<SyncCounts> loadCounts(String electionId) async {
    final accepted = await _statusCount(electionId, 'accepted');
    final pending = await _statusCount(electionId, 'pending');
    final rejected = await _statusCount(electionId, 'rejected');
    final conflict = await _statusCount(electionId, 'conflict');
    final participation =
        await _client
            .from('participation_records')
            .select('id')
            .eq('election_id', electionId)
            .count();
    return SyncCounts(
      accepted: accepted,
      pending: pending,
      rejected: rejected,
      conflict: conflict,
      participation: participation.count,
    );
  }

  Future<int> _statusCount(String electionId, String status) async {
    final response = await _client
        .from('sync_operations')
        .select('operation_id')
        .eq('election_id', electionId)
        .eq('status', status)
        .count();
    return response.count;
  }

  Future<Map<String?, int>> participationByTable(String electionId) async {
    final rows = await _client
        .from('participation_records')
        .select('voting_table_id')
        .eq('election_id', electionId);
    final result = <String?, int>{};
    for (final row in rows) {
      final key = row['voting_table_id'] as String?;
      result[key] = (result[key] ?? 0) + 1;
    }
    return result;
  }

  Future<List<Incident>> listIncidents(String electionId) async {
    final rows = await _client
        .from('electoral_incidents')
        .select('id, kind, status, description, resolution, created_at')
        .eq('election_id', electionId)
        .order('created_at', ascending: false);
    return rows.map(Incident.fromMap).toList();
  }

  Future<void> updateIncident({
    required String id,
    required String status,
    String? resolution,
  }) async {
    await _client.from('electoral_incidents').update({
      'status': status,
      'resolution': _blankToNull(resolution),
    }).eq('id', id);
  }

  static String? _blankToNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}