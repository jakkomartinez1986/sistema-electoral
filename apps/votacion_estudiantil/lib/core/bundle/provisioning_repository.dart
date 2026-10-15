import 'package:drift/drift.dart';

import 'package:electoral_core/electoral_core.dart';

import '../offline/app_database.dart';

/// Persiste y lee el paquete del dispositivo en la base local (drift).
///
/// El reemplazo del padrón y la configuración es atómico: si algo falla a mitad,
/// la base queda como estaba, de modo que la votación nunca ve datos a medias.
class ProvisioningRepository {
  ProvisioningRepository(this._db);

  final AppDatabase _db;

  static const String _currentId = 'current';

  /// Observa la configuración activa (o `null` si aún no se descargó nada).
  Stream<LocalConfigData?> watchConfig() =>
      (_db.select(_db.localConfig)
            ..where((t) => t.id.equals(_currentId)))
          .watchSingleOrNull();

  Future<LocalConfigData?> currentConfig() =>
      (_db.select(_db.localConfig)
            ..where((t) => t.id.equals(_currentId)))
          .getSingleOrNull();

  Future<int> countVoters() =>
      _db.localVoters.count().getSingle();

  /// Lista la oferta electoral descargada, ordenada por número de lista.
  Future<List<LocalList>> loadLists() =>
      (_db.select(_db.localLists)
            ..orderBy([(t) => OrderingTerm.asc(t.number)]))
          .get();

  /// Candidatos de todas las listas descargadas (se agrupan por `listId`).
  Future<List<LocalCandidate>> loadCandidates() =>
      (_db.select(_db.localCandidates)
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .get();

  /// Padrón local completo (referencias opacas y verificadores).
  Future<List<LocalVoter>> loadVoters() => _db.select(_db.localVoters).get();

  /// Guarda el bundle: reemplaza configuración, listas, candidatos y padrón.
  ///
  /// Conserva la participación local y el outbox (pertenecen a otra sesión de
  /// votación y no deben borrarse al re-descargar la configuración).
  Future<void> applyBundle(DeviceBundle bundle) async {
    final now = DateTime.now().toUtc();
    await _db.transaction(() async {
      // La participación local sobrevive a la re-descarga: se usa para
      // reaplicar la marca `hasVoted` al reinsertar el padrón, de modo que
      // re-descargar la configuración no rehabilite el voto en este equipo.
      final participation = await _db.select(_db.participationLocal).get();
      final votedAtByRef = {
        for (final row in participation) row.voterRef: row.castAt,
      };

      await _db.delete(_db.localVoters).go();
      await _db.delete(_db.localCandidates).go();
      await _db.delete(_db.localLists).go();
      await _db.delete(_db.localConfig).go();

      await _db
          .into(_db.localConfig)
          .insert(
            LocalConfigCompanion.insert(
              id: const Value(_currentId),
              electionId: bundle.config.election.id,
              electionName: bundle.config.election.name,
              electionStatus: bundle.config.election.status.name,
              timeZone: Value(bundle.config.election.timeZone),
              opensAt: Value(bundle.config.election.opensAt),
              closesAt: Value(bundle.config.election.closesAt),
              institutionId: bundle.institution.id,
              institutionName: bundle.institution.name,
              deviceId: bundle.device.deviceId,
              deviceUid: bundle.device.deviceUid,
              deviceLabel: bundle.device.label,
              votingTableId: Value(bundle.votingTable?.id),
              votingTableCode: Value(bundle.votingTable?.code),
              votingTableName: Value(bundle.votingTable?.name),
              verifierSalt: bundle.verifierSalt,
              configVersion: bundle.configVersion,
              configHash: bundle.configHash,
              listCount: Value(bundle.config.lists.length),
              candidateCount: Value(bundle.config.candidates.length),
              voterCount: Value(bundle.voters.length),
              downloadedAt: now,
              serverTime: bundle.serverTime,
            ),
          );

      for (final list in bundle.config.lists) {
        await _db
            .into(_db.localLists)
            .insert(
              LocalListsCompanion.insert(
                id: list.id,
                number: list.number,
                name: list.name,
                slogan: Value(list.slogan),
                emblemPath: Value(list.emblemPath),
              ),
            );
      }

      for (final candidate in bundle.config.candidates) {
        await _db
            .into(_db.localCandidates)
            .insert(
              LocalCandidatesCompanion.insert(
                id: candidate.id,
                listId: candidate.listId,
                fullName: candidate.fullName,
                position: candidate.position,
                orderIndex: Value(candidate.orderIndex),
                photoPath: Value(candidate.photoPath),
              ),
            );
      }

      for (final voter in bundle.voters) {
        final votedAt = votedAtByRef[voter.voterRef];
        await _db
            .into(_db.localVoters)
            .insert(
              LocalVotersCompanion.insert(
                voterRef: voter.voterRef,
                code: voter.code,
                votingTableId: Value(voter.votingTableId),
                cedulaVerifier: Value(voter.cedulaVerifier),
                pinVerifier: Value(voter.pinVerifier),
                hasVoted: Value(votedAt != null),
                votedAt: Value(votedAt),
              ),
            );
      }

      await _db
          .into(_db.syncLog)
          .insert(
            SyncLogCompanion.insert(
              level: 'info',
              message: 'Configuración y padrón descargados',
              detail: Value(
                'v${bundle.configVersion} · '
                '${bundle.config.lists.length} listas · '
                '${bundle.config.candidates.length} candidatos · '
                '${bundle.voters.length} votantes',
              ),
              createdAt: now,
            ),
          );
    });
  }
}
