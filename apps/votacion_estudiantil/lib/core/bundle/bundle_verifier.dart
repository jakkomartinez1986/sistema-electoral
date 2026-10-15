import 'package:electoral_core/electoral_core.dart';

/// Resumen de la verificación de un [DeviceBundle] antes de guardarlo.
///
/// No es una validación criptográfica del `config_hash` (el JSON del servidor no
/// es canónico byte a byte), sino una comprobación de integridad y coherencia
/// que evita habilitar la votación con datos incompletos.
class ProvisioningReport {
  const ProvisioningReport({
    required this.listCount,
    required this.candidateCount,
    required this.voterCount,
    required this.votersWithoutVerifier,
    required this.warnings,
    required this.configVersion,
    required this.configHash,
  });

  final int listCount;
  final int candidateCount;
  final int voterCount;
  final int votersWithoutVerifier;
  final List<String> warnings;
  final int configVersion;
  final String configHash;

  bool get isReady => warnings.isEmpty;
  bool get hasVoters => voterCount > 0;

  /// Hash abreviado para mostrar en pantalla.
  String get shortHash =>
      configHash.length <= 12 ? configHash : configHash.substring(0, 12);
}

/// Verifica la coherencia del paquete entregado por el servidor.
ProvisioningReport verifyBundle(DeviceBundle bundle) {
  final warnings = <String>[];

  if (bundle.config.lists.isEmpty) {
    warnings.add('La configuración no trae listas habilitadas.');
  }
  if (bundle.voters.isEmpty) {
    warnings.add('El padrón de esta mesa está vacío.');
  }

  final votersWithoutVerifier = bundle.voters.where((v) => v.isCodeOnly).length;
  if (votersWithoutVerifier > 0) {
    warnings.add(
      '$votersWithoutVerifier votante(s) sin cédula ni PIN '
      '(solo se pueden identificar por código).',
    );
  }

  final listIds = bundle.config.lists.map((l) => l.id).toSet();
  final orphans = bundle.config.candidates
      .where((c) => !listIds.contains(c.listId))
      .length;
  if (orphans > 0) {
    warnings.add('$orphans candidato(s) sin una lista válida.');
  }

  final tableId = bundle.assignment.votingTableId;
  if (tableId != null) {
    final outside = bundle.voters
        .where((v) => v.votingTableId != null && v.votingTableId != tableId)
        .length;
    if (outside > 0) {
      warnings.add('$outside votante(s) fuera de la mesa asignada.');
    }
  }

  return ProvisioningReport(
    listCount: bundle.config.lists.length,
    candidateCount: bundle.config.candidates.length,
    voterCount: bundle.voters.length,
    votersWithoutVerifier: votersWithoutVerifier,
    warnings: warnings,
    configVersion: bundle.configVersion,
    configHash: bundle.configHash,
  );
}
