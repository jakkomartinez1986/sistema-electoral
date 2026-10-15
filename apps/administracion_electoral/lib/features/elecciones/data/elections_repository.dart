import 'package:supabase_flutter/supabase_flutter.dart';

/// Estados de una elección (enum `election_status`), en orden de ciclo de vida.
const List<String> kElectionStatuses = <String>[
  'draft',
  'ready',
  'open',
  'closing',
  'closed',
  'archived',
  'cancelled',
];

String electionStatusLabel(String status) => switch (status) {
  'draft' => 'Borrador',
  'ready' => 'Lista',
  'open' => 'Abierta',
  'closing' => 'En cierre',
  'closed' => 'Cerrada',
  'archived' => 'Archivada',
  'cancelled' => 'Cancelada',
  _ => status,
};

/// Transiciones válidas que el backend acepta (espejo de `is_valid_transition`).
List<String> nextElectionStatuses(String status) => switch (status) {
  'draft' => const ['ready', 'cancelled'],
  'ready' => const ['open', 'draft', 'cancelled'],
  'open' => const ['closing', 'cancelled'],
  'closing' => const ['closed', 'open'],
  'closed' => const ['archived'],
  _ => const <String>[],
};

class Election {
  const Election({
    required this.id,
    required this.institutionId,
    required this.academicYearId,
    required this.name,
    required this.status,
    required this.timeZone,
    required this.configVersion,
    this.description,
    this.normativa,
    this.opensAt,
    this.closesAt,
  });

  final String id;
  final String institutionId;
  final String academicYearId;
  final String name;
  final String? description;
  final String? normativa;
  final String status;
  final String timeZone;
  final int configVersion;
  final DateTime? opensAt;
  final DateTime? closesAt;

  factory Election.fromMap(Map<String, Object?> map) => Election(
    id: map['id'] as String,
    institutionId: map['institution_id'] as String,
    academicYearId: map['academic_year_id'] as String,
    name: map['name'] as String,
    description: map['description'] as String?,
    normativa: map['normativa'] as String?,
    status: map['status'] as String,
    timeZone: map['time_zone'] as String,
    configVersion: (map['config_version'] as num).toInt(),
    opensAt: _parseTimestamp(map['opens_at']),
    closesAt: _parseTimestamp(map['closes_at']),
  );
}

/// Contadores de conciliación de una elección (sin identidad del votante).
///
/// `readyToClose` es falso mientras queden operaciones `pending` o incidencias
/// abiertas/en revisión: el backend rechaza el cierre en ese caso.
class ElectionReconciliation {
  const ElectionReconciliation({
    required this.pendingOperations,
    required this.conflictOperations,
    required this.openIncidents,
    required this.readyToClose,
  });

  final int pendingOperations;
  final int conflictOperations;
  final int openIncidents;
  final bool readyToClose;

  factory ElectionReconciliation.fromMap(Map<String, Object?> map) =>
      ElectionReconciliation(
        pendingOperations: (map['pending_operations'] as num?)?.toInt() ?? 0,
        conflictOperations: (map['conflict_operations'] as num?)?.toInt() ?? 0,
        openIncidents: (map['open_incidents'] as num?)?.toInt() ?? 0,
        readyToClose: map['ready_to_close'] == true,
      );
}

class VotingTable {
  const VotingTable({
    required this.id,
    required this.electionId,
    required this.code,
    this.name,
    this.capacity,
    this.courseId,
  });

  final String id;
  final String electionId;
  final String code;
  final String? name;
  final int? capacity;
  final String? courseId;

  factory VotingTable.fromMap(Map<String, Object?> map) => VotingTable(
    id: map['id'] as String,
    electionId: map['election_id'] as String,
    code: map['code'] as String,
    name: map['name'] as String?,
    capacity: (map['capacity'] as num?)?.toInt(),
    courseId: map['course_id'] as String?,
  );
}

DateTime? _parseTimestamp(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

class ElectionsRepository {
  ElectionsRepository(this._client);

  final SupabaseClient _client;

  static const String _columns =
      'id, institution_id, academic_year_id, name, description, normativa, '
      'status, time_zone, config_version, opens_at, closes_at';

  Future<List<Election>> listElections(String institutionId) async {
    final rows = await _client
        .from('elections')
        .select(_columns)
        .eq('institution_id', institutionId)
        .order('created_at', ascending: false);
    return rows.map(Election.fromMap).toList();
  }

  Future<void> createElection({
    required String institutionId,
    required String academicYearId,
    required String name,
    String? description,
    String? normativa,
    required String timeZone,
    DateTime? opensAt,
    DateTime? closesAt,
  }) async {
    await _client.from('elections').insert({
      'institution_id': institutionId,
      'academic_year_id': academicYearId,
      'name': name,
      'description': _blankToNull(description),
      'normativa': _blankToNull(normativa),
      'time_zone': timeZone,
      'opens_at': opensAt?.toUtc().toIso8601String(),
      'closes_at': closesAt?.toUtc().toIso8601String(),
    });
  }

  Future<void> updateElection(
    String id, {
    required String name,
    String? description,
    String? normativa,
    required String timeZone,
    DateTime? opensAt,
    DateTime? closesAt,
  }) async {
    await _client.from('elections').update({
      'name': name,
      'description': _blankToNull(description),
      'normativa': _blankToNull(normativa),
      'time_zone': timeZone,
      'opens_at': opensAt?.toUtc().toIso8601String(),
      'closes_at': closesAt?.toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> transitionElection(String id, String newStatus) async {
    await _client.rpc(
      'transition_election',
      params: {'p_election_id': id, 'p_new_status': newStatus},
    );
  }

  Future<ElectionReconciliation> reconciliation(String id) async {
    final result = await _client.rpc(
      'election_reconciliation',
      params: {'p_election_id': id},
    );
    return ElectionReconciliation.fromMap((result as Map).cast<String, Object?>());
  }

  Future<String> generateConfig(String id) async {
    final result = await _client.rpc(
      'generate_election_config',
      params: {'p_election_id': id},
    );
    final map = (result as Map).cast<String, Object?>();
    return '${map['hash']}';
  }

  Future<List<VotingTable>> listTables(String electionId) async {
    final rows = await _client
        .from('voting_tables')
        .select('id, election_id, code, name, capacity, course_id')
        .eq('election_id', electionId)
        .order('code');
    return rows.map(VotingTable.fromMap).toList();
  }

  Future<void> createTable({
    required String electionId,
    required String code,
    String? name,
    int? capacity,
    String? courseId,
  }) async {
    await _client.from('voting_tables').insert({
      'election_id': electionId,
      'code': code,
      'name': _blankToNull(name),
      'capacity': capacity,
      'course_id': courseId,
    });
  }

  Future<void> updateTable(
    String id, {
    required String code,
    String? name,
    int? capacity,
    String? courseId,
  }) async {
    await _client.from('voting_tables').update({
      'code': code,
      'name': _blankToNull(name),
      'capacity': capacity,
      'course_id': courseId,
    }).eq('id', id);
  }

  Future<void> deleteTable(String id) async {
    await _client.from('voting_tables').delete().eq('id', id);
  }

  static String? _blankToNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
