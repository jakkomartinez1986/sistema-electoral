import 'package:drift/drift.dart';
import 'package:electoral_core/electoral_core.dart';
import 'package:uuid/uuid.dart';

import '../bundle/provisioning_repository.dart';
import '../offline/app_database.dart';

/// Error al registrar un voto en el dispositivo.
class VotingException implements Exception {
  const VotingException(this.code);

  final String code;

  String get message => switch (code) {
    'not_provisioned' =>
      'Este equipo todavía no tiene la configuración y el padrón descargados.',
    'voter_not_found' => 'El votante no está en el padrón de este equipo.',
    'already_voted' => 'Este estudiante ya registró su voto en este equipo.',
    'election_closed' => 'La votación no está abierta en este momento.',
    _ => 'No se pudo registrar el voto ($code).',
  };

  @override
  String toString() => 'VotingException($code)';
}

/// Comprobante local de un voto registrado (aún sin sincronizar).
class CastReceipt {
  const CastReceipt({
    required this.operationId,
    required this.ballotId,
    required this.option,
    required this.castAt,
  });

  final String operationId;
  final String ballotId;
  final BallotOption option;
  final DateTime castAt;

  /// Prefijo corto para mostrar en pantalla sin exponer el UUID completo.
  String get shortOperationId => operationId.length <= 8
      ? operationId
      : operationId.substring(0, 8);
}

/// Registra un voto **localmente** y lo deja listo para sincronizar.
///
/// La participación y la operación se escriben en una única transacción: si algo
/// falla, no queda ni marca de participación ni operación encolada. El contenido
/// del voto no se enlaza a la identidad en el servidor; la separación se resuelve
/// en el backend (`cast_ballot`).
class VotingRepository {
  VotingRepository(this._db, this._provisioning, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final ProvisioningRepository _provisioning;
  final Uuid _uuid;

  Future<CastReceipt> recordVote({
    required String voterRef,
    required BallotOption option,
  }) async {
    final now = DateTime.now().toUtc();
    late final String operationId;
    late final String ballotId;

    await _db.transaction(() async {
      final config = await _provisioning.currentConfig();
      if (config == null) throw const VotingException('not_provisioned');

      final status = ElectionStatus.fromDb(config.electionStatus);
      if (!status.acceptsBallots) throw const VotingException('election_closed');

      final voter = await (_db.select(_db.localVoters)
            ..where((t) => t.voterRef.equals(voterRef)))
          .getSingleOrNull();
      if (voter == null) throw const VotingException('voter_not_found');
      if (voter.hasVoted) throw const VotingException('already_voted');

      operationId = _uuid.v4();
      ballotId = _uuid.v4();

      await _db.into(_db.participationLocal).insert(
            ParticipationLocalCompanion.insert(
              voterRef: voterRef,
              operationId: operationId,
              castAt: now,
            ),
          );

      await _db.into(_db.outbox).insert(
            OutboxCompanion.insert(
              operationId: operationId,
              voterRef: voterRef,
              optionType: option.type.dbValue,
              candidateListId: Value(option.candidateListId),
              ballotId: ballotId,
              createdAt: now,
              updatedAt: now,
            ),
          );

      await (_db.update(_db.localVoters)
            ..where((t) => t.voterRef.equals(voterRef)))
          .write(
        LocalVotersCompanion(
          hasVoted: const Value(true),
          votedAt: Value(now),
        ),
      );

      await _db.into(_db.syncLog).insert(
            SyncLogCompanion.insert(
              level: 'info',
              message: 'Voto registrado localmente',
              detail: Value(
                'operación $operationId · ${option.type.dbValue}',
              ),
              createdAt: now,
            ),
          );
    });

    return CastReceipt(
      operationId: operationId,
      ballotId: ballotId,
      option: option,
      castAt: now,
    );
  }
}
