import 'package:electoral_core/electoral_core.dart';

import '../bundle/provisioning_repository.dart';
import '../offline/app_database.dart';

/// Identificación de un votante en el padrón local más el estado de su
/// participación **en este dispositivo**.
///
/// El servidor decide en última instancia si acepta el voto (`cast_ballot`); la
/// marca local solo evita habilitar dos papeletas seguidas en el mismo equipo.
class VoterIdentification {
  const VoterIdentification(
    this.result, {
    this.hasVoted = false,
    this.votedAt,
  });

  final VoterMatchResult result;
  final bool hasVoted;
  final DateTime? votedAt;

  String? get voterRef => result.voterRef;

  bool get found => result.found;

  /// Hay coincidencia y el votante todavía no ha votado en este equipo.
  bool get canVote => found && !hasVoted;
}

/// Identifica votantes contra el padrón descargado, sin conexión.
///
/// La comparación de credenciales es pura (vive en `electoral_core`); aquí solo
/// se leen las filas del padrón local y se resuelve el estado de participación.
class PadronRepository {
  PadronRepository(this._db, this._provisioning);

  final AppDatabase _db;
  final ProvisioningRepository _provisioning;

  /// Proyecta el padrón local a las entradas que usa [VoterLookup].
  Future<List<PadronEntry>> entries() async {
    final rows = await _provisioning.loadVoters();
    return [
      for (final row in rows)
        PadronEntry(
          voterRef: row.voterRef,
          code: row.code,
          cedulaVerifier: row.cedulaVerifier,
          pinVerifier: row.pinVerifier,
        ),
    ];
  }

  Future<VoterIdentification> identifyByCedula(String cedula) async {
    final config = await _provisioning.currentConfig();
    if (config == null) return const VoterIdentification(VoterMatchResult.notFound);
    final result = VoterLookup.byCedula(
      salt: config.verifierSalt,
      cedula: cedula,
      padron: await entries(),
    );
    return _resolve(result);
  }

  Future<VoterIdentification> identifyByCode({
    required String code,
    required String pin,
  }) async {
    final config = await _provisioning.currentConfig();
    if (config == null) return const VoterIdentification(VoterMatchResult.notFound);
    final result = VoterLookup.byCode(
      salt: config.verifierSalt,
      code: code,
      pin: pin,
      padron: await entries(),
    );
    return _resolve(result);
  }

  Future<VoterIdentification> _resolve(VoterMatchResult result) async {
    final ref = result.voterRef;
    if (ref == null) return VoterIdentification(result);

    final row = await (_db.select(_db.localVoters)
          ..where((t) => t.voterRef.equals(ref)))
        .getSingleOrNull();
    return VoterIdentification(
      result,
      hasVoted: row?.hasVoted ?? false,
      votedAt: row?.votedAt,
    );
  }
}
