import '../constants.dart';

/// Carga entregada por el RPC `get_device_bundle` a un dispositivo autorizado.
///
/// Contiene la configuración de la elección (listas y candidatos), el padrón de
/// la mesa con verificadores opacos y los metadatos de la asignación. No incluye
/// nombres ni cédulas en claro.
class DeviceBundle {
  const DeviceBundle({
    required this.device,
    required this.institution,
    required this.assignment,
    required this.verifierSalt,
    required this.config,
    required this.configVersion,
    required this.configHash,
    required this.voters,
    required this.serverTime,
    this.votingTable,
  });

  final BundleDevice device;
  final BundleInstitution institution;
  final BundleAssignment assignment;

  /// Mesa asignada; `null` si el dispositivo cubre el padrón completo.
  final BundleVotingTable? votingTable;

  /// Sal definida por el servidor para los verificadores (id de institución).
  final String verifierSalt;

  final BundleConfig config;
  final int configVersion;
  final String configHash;
  final List<BundleVoter> voters;
  final DateTime serverTime;

  factory DeviceBundle.fromJson(Map<String, Object?> json) {
    final table = json['voting_table'];
    return DeviceBundle(
      device: BundleDevice.fromJson(json['device'] as Map<String, Object?>),
      institution: BundleInstitution.fromJson(
        json['institution'] as Map<String, Object?>,
      ),
      assignment: BundleAssignment.fromJson(
        json['assignment'] as Map<String, Object?>,
      ),
      votingTable: table == null
          ? null
          : BundleVotingTable.fromJson(table as Map<String, Object?>),
      verifierSalt: json['verifier_salt'] as String,
      config: BundleConfig.fromJson(json['config'] as Map<String, Object?>),
      configVersion: (json['config_version'] as num).toInt(),
      configHash: json['config_hash'] as String,
      voters: (json['voters'] as List<Object?>)
          .map((e) => BundleVoter.fromJson(e as Map<String, Object?>))
          .toList(growable: false),
      serverTime: DateTime.parse(json['server_time'] as String).toUtc(),
    );
  }
}

class BundleDevice {
  const BundleDevice({
    required this.deviceId,
    required this.deviceUid,
    required this.label,
  });

  final String deviceId;
  final String deviceUid;
  final String label;

  factory BundleDevice.fromJson(Map<String, Object?> json) => BundleDevice(
    deviceId: json['device_id'] as String,
    deviceUid: json['device_uid'] as String,
    label: json['label'] as String,
  );
}

class BundleInstitution {
  const BundleInstitution({
    required this.id,
    required this.name,
    required this.timeZone,
  });

  final String id;
  final String name;
  final String timeZone;

  factory BundleInstitution.fromJson(Map<String, Object?> json) =>
      BundleInstitution(
        id: json['id'] as String,
        name: json['name'] as String,
        timeZone: (json['time_zone'] as String?) ?? kDefaultTimeZone,
      );
}

class BundleAssignment {
  const BundleAssignment({
    required this.electionId,
    required this.votingTableId,
    required this.configVersion,
    this.authorizedAt,
  });

  final String electionId;
  final String? votingTableId;
  final int configVersion;
  final DateTime? authorizedAt;

  factory BundleAssignment.fromJson(Map<String, Object?> json) {
    final at = json['authorized_at'];
    return BundleAssignment(
      electionId: json['election_id'] as String,
      votingTableId: json['voting_table_id'] as String?,
      configVersion: (json['config_version'] as num).toInt(),
      authorizedAt: at == null ? null : DateTime.parse(at as String).toUtc(),
    );
  }
}

class BundleVotingTable {
  const BundleVotingTable({
    required this.id,
    required this.code,
    this.name,
  });

  final String id;
  final String code;
  final String? name;

  factory BundleVotingTable.fromJson(Map<String, Object?> json) =>
      BundleVotingTable(
        id: json['id'] as String,
        code: json['code'] as String,
        name: json['name'] as String?,
      );
}

class BundleConfig {
  const BundleConfig({
    required this.election,
    required this.lists,
    required this.candidates,
  });

  final BundleElection election;
  final List<BundleList> lists;
  final List<BundleCandidate> candidates;

  factory BundleConfig.fromJson(Map<String, Object?> json) => BundleConfig(
    election: BundleElection.fromJson(
      json['election'] as Map<String, Object?>,
    ),
    lists: (json['lists'] as List<Object?>)
        .map((e) => BundleList.fromJson(e as Map<String, Object?>))
        .toList(growable: false),
    candidates: (json['candidates'] as List<Object?>)
        .map((e) => BundleCandidate.fromJson(e as Map<String, Object?>))
        .toList(growable: false),
  );

  /// Candidatos de una lista, ordenados.
  List<BundleCandidate> candidatesOf(String listId) => candidates
      .where((c) => c.listId == listId)
      .toList(growable: false)
    ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
}

class BundleElection {
  const BundleElection({
    required this.id,
    required this.name,
    required this.status,
    this.description,
    this.normativa,
    this.timeZone = kDefaultTimeZone,
    this.opensAt,
    this.closesAt,
    this.configVersion = 1,
  });

  final String id;
  final String name;
  final ElectionStatus status;
  final String? description;
  final String? normativa;
  final String timeZone;
  final DateTime? opensAt;
  final DateTime? closesAt;
  final int configVersion;

  factory BundleElection.fromJson(Map<String, Object?> json) {
    DateTime? date(Object? v) =>
        v == null ? null : DateTime.parse(v as String).toUtc();
    return BundleElection(
      id: json['id'] as String,
      name: json['name'] as String,
      status: ElectionStatus.fromDb(json['status'] as String),
      description: json['description'] as String?,
      normativa: json['normativa'] as String?,
      timeZone: (json['time_zone'] as String?) ?? kDefaultTimeZone,
      opensAt: date(json['opens_at']),
      closesAt: date(json['closes_at']),
      configVersion: (json['config_version'] as num?)?.toInt() ?? 1,
    );
  }
}

class BundleList {
  const BundleList({
    required this.id,
    required this.number,
    required this.name,
    this.slogan,
    this.emblemPath,
  });

  final String id;
  final int number;
  final String name;
  final String? slogan;
  final String? emblemPath;

  factory BundleList.fromJson(Map<String, Object?> json) => BundleList(
    id: json['id'] as String,
    number: (json['number'] as num).toInt(),
    name: json['name'] as String,
    slogan: json['slogan'] as String?,
    emblemPath: json['emblem_path'] as String?,
  );
}

class BundleCandidate {
  const BundleCandidate({
    required this.id,
    required this.listId,
    required this.fullName,
    required this.position,
    this.orderIndex = 0,
    this.photoPath,
  });

  final String id;
  final String listId;
  final String fullName;
  final String position;
  final int orderIndex;
  final String? photoPath;

  factory BundleCandidate.fromJson(Map<String, Object?> json) =>
      BundleCandidate(
        id: json['id'] as String,
        listId: json['list_id'] as String,
        fullName: json['full_name'] as String,
        position: json['position'] as String,
        orderIndex: (json['order_index'] as num?)?.toInt() ?? 0,
        photoPath: json['photo_path'] as String?,
      );
}

/// Votante del padrón: solo referencia opaca + verificadores.
class BundleVoter {
  const BundleVoter({
    required this.voterRef,
    required this.code,
    this.votingTableId,
    this.cedulaVerifier,
    this.pinVerifier,
  });

  /// Identificador opaco que viaja a la papeleta.
  final String voterRef;

  /// Código estudiantil interno (identifica, no es secreto sensible).
  final String code;

  final String? votingTableId;

  /// Verificador derivado de la cédula; `null` si el estudiante no tiene.
  final String? cedulaVerifier;

  /// Verificador derivado del PIN; `null` si no se configuró.
  final String? pinVerifier;

  /// Ni cédula ni PIN: solo se puede identificar por código (menos seguro).
  bool get isCodeOnly => cedulaVerifier == null && pinVerifier == null;

  factory BundleVoter.fromJson(Map<String, Object?> json) => BundleVoter(
    voterRef: json['voter_ref'] as String,
    code: json['code'] as String,
    votingTableId: json['voting_table_id'] as String?,
    cedulaVerifier: json['cedula_verifier'] as String?,
    pinVerifier: json['pin_verifier'] as String?,
  );
}
