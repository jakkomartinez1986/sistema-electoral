import 'package:supabase_flutter/supabase_flutter.dart';

/// Estados posibles de un dispositivo (enum `device_status`).
const List<String> kDeviceStatuses = <String>['pending', 'authorized', 'revoked'];

String deviceStatusLabel(String status) => switch (status) {
  'pending' => 'Pendiente',
  'authorized' => 'Autorizado',
  'revoked' => 'Revocado',
  _ => status,
};

/// Dispositivo de votación registrado.
class VotingDevice {
  const VotingDevice({
    required this.id,
    required this.institutionId,
    required this.deviceUid,
    required this.label,
    required this.status,
    this.appVersion,
    this.lastSeenAt,
  });

  final String id;
  final String institutionId;
  final String deviceUid;
  final String label;
  final String status;
  final String? appVersion;
  final DateTime? lastSeenAt;

  factory VotingDevice.fromMap(Map<String, Object?> map) => VotingDevice(
    id: map['id'] as String,
    institutionId: map['institution_id'] as String,
    deviceUid: map['device_uid'] as String,
    label: map['label'] as String,
    status: map['status'] as String,
    appVersion: map['app_version'] as String?,
    lastSeenAt: _parseTimestamp(map['last_seen_at']),
  );
}

/// Asignación dispositivo ↔ elección ↔ mesa.
class DeviceAssignment {
  const DeviceAssignment({
    required this.id,
    required this.deviceId,
    required this.electionId,
    required this.configVersion,
    this.votingTableId,
    this.revokedAt,
  });

  final String id;
  final String deviceId;
  final String electionId;
  final String? votingTableId;
  final int configVersion;
  final DateTime? revokedAt;

  factory DeviceAssignment.fromMap(Map<String, Object?> map) =>
      DeviceAssignment(
        id: map['id'] as String,
        deviceId: map['device_id'] as String,
        electionId: map['election_id'] as String,
        votingTableId: map['voting_table_id'] as String?,
        configVersion: (map['config_version'] as num).toInt(),
        revokedAt: _parseTimestamp(map['revoked_at']),
      );
}

DateTime? _parseTimestamp(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

class DevicesRepository {
  DevicesRepository(this._client);

  final SupabaseClient _client;

  Future<List<VotingDevice>> listDevices(String institutionId) async {
    final rows = await _client
        .from('voting_devices')
        .select(
          'id, institution_id, device_uid, label, status, app_version, '
          'last_seen_at',
        )
        .eq('institution_id', institutionId)
        .order('created_at', ascending: false);
    return rows.map(VotingDevice.fromMap).toList();
  }

  Future<void> createDevice({
    required String institutionId,
    required String deviceUid,
    required String label,
  }) async {
    await _client.from('voting_devices').insert({
      'institution_id': institutionId,
      'device_uid': deviceUid,
      'label': label,
    });
  }

  Future<void> updateDevice(
    String id, {
    required String deviceUid,
    required String label,
    required String status,
  }) async {
    await _client.from('voting_devices').update({
      'device_uid': deviceUid,
      'label': label,
      'status': status,
    }).eq('id', id);
  }

  Future<List<DeviceAssignment>> listAssignments(String deviceId) async {
    final rows = await _client
        .from('device_assignments')
        .select(
          'id, device_id, election_id, voting_table_id, config_version, '
          'revoked_at',
        )
        .eq('device_id', deviceId)
        .order('authorized_at', ascending: false);
    return rows.map(DeviceAssignment.fromMap).toList();
  }

  Future<void> assignDevice({
    required String deviceId,
    required String electionId,
    String? votingTableId,
  }) async {
    await _client.from('device_assignments').insert({
      'device_id': deviceId,
      'election_id': electionId,
      'voting_table_id': votingTableId,
    });
  }

  Future<void> revokeAssignment(String id) async {
    await _client
        .from('device_assignments')
        .update({'revoked_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  /// Genera un código de emparejamiento de un solo uso; devuelve el texto.
  Future<String> createEnrollmentCode(String deviceId, int ttlMinutes) async {
    final result = await _client.rpc(
      'create_enrollment_code',
      params: {'p_device_id': deviceId, 'p_ttl_minutes': ttlMinutes},
    );
    final map = (result as Map).cast<String, Object?>();
    return map['code'] as String;
  }
}