import 'package:drift/drift.dart';
import 'package:electoral_core/electoral_core.dart';

import '../offline/app_database.dart';
import 'ballot_gateway.dart';

/// Resultado de una pasada de sincronización de la cola de salida.
class SyncSummary {
  int checked = 0;
  int accepted = 0;
  int rejected = 0;
  int conflict = 0;
  int pending = 0;
  int errors = 0;

  int get finished => accepted + rejected + conflict;

  /// Quedan operaciones sin confirmar por el servidor.
  bool get hasOutstanding => pending > 0 || errors > 0;

  @override
  String toString() =>
      'SyncSummary(checked: $checked, accepted: $accepted, rejected: $rejected, '
      'conflict: $conflict, pending: $pending, errors: $errors)';
}

/// Envía la cola local (`outbox`) al backend con reintentos e idempotencia.
///
/// - Reintentos con **backoff exponencial + jitter** (determinista por operación)
///   y un máximo de intentos.
/// - Idempotencia por `operation_id`: reenviar el mismo UUID nunca duplica.
/// - Ante un fallo de red **no** se asume fallo: se consulta el estado real con
///   `get_operation_status` antes de volver a intentar.
/// - Los registros no se borran mientras no estén confirmados ni rechazados.
class OutboxSender {
  OutboxSender(
    this._db,
    this._gateway, {
    this.maxAttempts = 8,
    this.baseDelay = const Duration(seconds: 5),
    this.maxDelay = const Duration(minutes: 5),
  });

  final AppDatabase _db;
  final BallotCastApi _gateway;
  final int maxAttempts;
  final Duration baseDelay;
  final Duration maxDelay;

  /// Estados desde los que se puede reintentar.
  static const List<String> retryableStatuses = ['pending', 'error'];

  /// Envía las operaciones pendientes. Con [force] se ignora el backoff (p. ej.
  /// una sincronización manual autorizada del operador).
  Future<SyncSummary> sendPending({bool force = false}) async {
    final rows = await (_db.select(_db.outbox)
          ..where((t) => t.status.isIn(retryableStatuses))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();

    final summary = SyncSummary();
    final now = DateTime.now().toUtc();
    for (final row in rows) {
      if (!force && !_isDue(row, now)) {
        summary.pending++;
        continue;
      }
      await _send(row, summary, now);
    }
    return summary;
  }

  /// Cuántas operaciones siguen sin confirmarse (para el indicador en pantalla).
  Stream<int> watchPendingCount() {
    final count = _db.outbox.operationId.count();
    final query = _db.selectOnly(_db.outbox)
      ..addColumns([count])
      ..where(
        _db.outbox.status.isIn([...retryableStatuses, 'sending']),
      );
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  bool _isDue(OutboxData row, DateTime now) {
    if (row.attempts == 0) return true;
    if (row.attempts >= maxAttempts) return false;
    return !now.isBefore(row.updatedAt.add(_backoff(row.attempts, row.operationId)));
  }

  /// Backoff exponencial con jitter determinista (para poder probarlo).
  Duration _backoff(int attempts, String seed) {
    final shift = (attempts - 1).clamp(0, 20);
    var millis = baseDelay.inMilliseconds * (1 << shift);
    if (millis > maxDelay.inMilliseconds) millis = maxDelay.inMilliseconds;
    final jitter = seed.hashCode.abs() % (millis ~/ 4 + 1);
    return Duration(milliseconds: millis + jitter);
  }

  Future<void> _send(OutboxData row, SyncSummary summary, DateTime now) async {
    summary.checked++;
    await (_db.update(_db.outbox)
          ..where((t) => t.operationId.equals(row.operationId)))
        .write(
      OutboxCompanion(
        status: const Value('sending'),
        attempts: Value(row.attempts + 1),
        updatedAt: Value(now),
      ),
    );

    final option = BallotOption.fromDb(
      optionType: row.optionType,
      candidateListId: row.candidateListId,
    );

    try {
      final result = await _gateway.castBallot(
        operationId: row.operationId,
        voterRef: row.voterRef,
        option: option,
        ballotId: row.ballotId,
      );
      await _finalize(row, result.status, result.errorCode);
      _count(summary, result.status);
    } on BallotRejectionException catch (error) {
      await _finalize(row, SyncOperationStatus.rejected, error.code);
      summary.rejected++;
    } on BallotNetworkException {
      // Resultado incierto: comprobar el estado real antes de reintentar.
      final recovered = await _recover(row.operationId);
      if (recovered == null) {
        await _revertToPending(row, 'sin conexión');
        summary.errors++;
      } else {
        await _finalize(row, recovered.status!, recovered.errorCode);
        _count(summary, recovered.status!);
      }
    } catch (_) {
      await _revertToPending(row, 'error inesperado');
      summary.errors++;
    }
  }

  Future<OperationStatus?> _recover(String operationId) async {
    try {
      final status = await _gateway.getOperationStatus(operationId);
      return status.isUnknown ? null : status;
    } catch (_) {
      return null;
    }
  }

  Future<void> _finalize(
    OutboxData row,
    SyncOperationStatus status,
    String? errorCode,
  ) async {
    final now = DateTime.now().toUtc();
    final outboxStatus = switch (status) {
      SyncOperationStatus.accepted => 'accepted',
      SyncOperationStatus.rejected => 'rejected',
      SyncOperationStatus.conflict => 'conflict',
      SyncOperationStatus.pending => 'pending',
    };
    await (_db.update(_db.outbox)
          ..where((t) => t.operationId.equals(row.operationId)))
        .write(
      OutboxCompanion(
        status: Value(outboxStatus),
        lastError: Value(errorCode),
        updatedAt: Value(now),
      ),
    );

    if (status == SyncOperationStatus.accepted) {
      await (_db.update(_db.participationLocal)
            ..where((t) => t.operationId.equals(row.operationId)))
          .write(const ParticipationLocalCompanion(synced: Value(true)));
    }

    await _log(
      status == SyncOperationStatus.accepted ? 'info' : 'warning',
      'Sincronización: ${status.name}',
      '${row.operationId}${errorCode == null ? '' : ' · $errorCode'}',
      now,
    );
  }

  Future<void> _revertToPending(OutboxData row, String reason) async {
    final now = DateTime.now().toUtc();
    await (_db.update(_db.outbox)
          ..where((t) => t.operationId.equals(row.operationId)))
        .write(
      OutboxCompanion(
        status: const Value('error'),
        lastError: Value(reason),
        updatedAt: Value(now),
      ),
    );
    await _log(
      'warning',
      'Voto pendiente de sincronizar',
      '${row.operationId} · $reason',
      now,
    );
  }

  Future<void> _log(
    String level,
    String message,
    String? detail,
    DateTime now,
  ) =>
      _db.into(_db.syncLog).insert(
            SyncLogCompanion.insert(
              level: level,
              message: message,
              detail: Value(detail),
              createdAt: now,
            ),
          );

  void _count(SyncSummary summary, SyncOperationStatus status) {
    switch (status) {
      case SyncOperationStatus.accepted:
        summary.accepted++;
      case SyncOperationStatus.rejected:
        summary.rejected++;
      case SyncOperationStatus.conflict:
        summary.conflict++;
      case SyncOperationStatus.pending:
        summary.pending++;
    }
  }
}
