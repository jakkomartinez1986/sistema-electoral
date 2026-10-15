/// Constantes del dominio electoral.
library;

/// Zona horaria institucional por defecto (Ecuador continental).
///
/// Se almacena y se muestra de forma explícita: la especificación exige una
/// zona horaria configurable y fechas consistentes. Nunca dependemos de la
/// hora local implícita del dispositivo para decidir apertura o cierre.
const String kDefaultTimeZone = 'America/Guayaquil';

/// Zonas horarias válidas para una institución ecuatoriana.
const Set<String> kSupportedTimeZones = {
  'America/Guayaquil',
  'Pacific/Galapagos',
};

/// Estados posibles de una elección (máquina de estados).
///
/// Las transiciones válidas viven en el backend; aquí solo se declaran los
/// valores para que ambas apps los entiendan igual.
enum ElectionStatus {
  draft,
  ready,
  open,
  closing,
  closed,
  archived,
  cancelled;

  /// Interpreta el valor almacenado en PostgreSQL (`text`).
  static ElectionStatus fromDb(String value) {
    for (final s in ElectionStatus.values) {
      if (s.name == value) return s;
    }
    throw ArgumentError('Estado de elección desconocido: $value');
  }

  /// Estados en los que se aceptan nuevas papeletas.
  bool get acceptsBallots => this == ElectionStatus.open;

  /// Estados en los que los resultados pueden consolidarse/publicarse.
  bool get isConsolidable => this == ElectionStatus.closed;
}

/// Opción depositada en una papeleta.
///
/// El modelo solo admite tres formas, tal como exige la especificación:
/// una lista habilitada, voto blanco o voto nulo.
enum BallotOptionType {
  candidateList,
  blank,
  nullVote;

  static BallotOptionType fromDb(String value) => switch (value) {
        'list' => BallotOptionType.candidateList,
        'blank' => BallotOptionType.blank,
        'null' => BallotOptionType.nullVote,
        _ => throw ArgumentError('Tipo de voto desconocido: $value'),
      };

  /// Valor canónico almacenado en PostgreSQL (columna `option_type`).
  String get dbValue => switch (this) {
        BallotOptionType.candidateList => 'list',
        BallotOptionType.blank => 'blank',
        BallotOptionType.nullVote => 'null',
      };

  /// Etiqueta legible para interfaces.
  String get label => switch (this) {
        BallotOptionType.candidateList => 'Lista',
        BallotOptionType.blank => 'Voto en blanco',
        BallotOptionType.nullVote => 'Voto nulo',
      };
}

/// Estado de un dispositivo de votación autorizado.
enum DeviceStatus {
  pending,
  authorized,
  revoked;

  static DeviceStatus fromDb(String value) {
    for (final s in DeviceStatus.values) {
      if (s.name == value) return s;
    }
    throw ArgumentError('Estado de dispositivo desconocido: $value');
  }
}

/// Estado de una operación de sincronización (outbox / ledger del servidor).
enum SyncOperationStatus {
  pending,
  accepted,
  rejected,
  conflict;

  static SyncOperationStatus fromDb(String value) {
    for (final s in SyncOperationStatus.values) {
      if (s.name == value) return s;
    }
    throw ArgumentError('Estado de operación desconocido: $value');
  }
}

/// Roles del personal autorizado.
enum UserRole {
  admin,
  operator,
  tutor;

  static UserRole fromDb(String value) {
    for (final r in UserRole.values) {
      if (r.name == value) return r;
    }
    throw ArgumentError('Rol desconocido: $value');
  }
}
