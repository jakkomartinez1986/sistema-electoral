import '../constants.dart';

/// Resultado devuelto por el RPC `cast_ballot`.
///
/// El backend concentra toda la decisión: el cliente solo interpreta el estado.
/// Nunca contiene el identificador del votante.
class CastBallotResult {
  const CastBallotResult({
    required this.operationId,
    required this.status,
    this.errorCode,
    this.duplicate = false,
  });

  /// Identificador de la operación enviada (idempotencia).
  final String operationId;

  /// Estado resuelto en el servidor.
  final SyncOperationStatus status;

  /// Motivo de rechazo, cuando aplica (`voter_not_found`, `device_not_authorized`,
  /// `outside_window`, `duplicate_participation`, ...).
  final String? errorCode;

  /// `true` cuando el servidor ya había procesado esa misma operación.
  final bool duplicate;

  /// ¿La papeleta quedó registrada?
  bool get accepted => status == SyncOperationStatus.accepted;

  factory CastBallotResult.fromJson(Map<String, Object?> json) {
    return CastBallotResult(
      operationId: json['operation_id'] as String,
      status: SyncOperationStatus.fromDb(json['status'] as String),
      errorCode: json['error_code'] as String?,
      duplicate: (json['duplicate'] as bool?) ?? false,
    );
  }

  @override
  String toString() =>
      'CastBallotResult($operationId, ${status.name}'
      '${errorCode == null ? '' : ', $errorCode'}'
      '${duplicate ? ', duplicate' : ''})';
}
