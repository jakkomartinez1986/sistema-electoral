import 'package:electoral_core/electoral_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fallo **transitorio**: no se pudo determinar el resultado (red, timeout o
/// respuesta inesperada). La operación no se marca como fallida: se reintenta y,
/// por idempotencia, nunca se duplica.
class BallotNetworkException implements Exception {
  const BallotNetworkException([this.code = 'network']);

  final String code;

  @override
  String toString() => 'BallotNetworkException($code)';
}

/// Rechazo **controlado** del servidor: el dispositivo o su asignación dejaron
/// de ser válidos. Reintentar no ayuda; el operador debe actuar.
class BallotRejectionException implements Exception {
  const BallotRejectionException(this.code);

  final String code;

  String get message => switch (code) {
    'device_not_authorized' =>
      'Este equipo ya no está autorizado. Pide al personal electoral que lo '
          'habilite.',
    'device_not_assigned' =>
      'El equipo no tiene una asignación vigente para esta elección.',
    'not_authenticated' =>
      'La sesión del dispositivo expiró. Vuelve a vincularlo.',
    'not_allowed' => 'El servidor rechazó la operación.',
    _ => 'El servidor rechazó la operación ($code).',
  };

  @override
  String toString() => 'BallotRejectionException($code)';
}

/// Estado de una operación consultada por su UUID (`get_operation_status`).
class OperationStatus {
  const OperationStatus(this.operationId, this.status, {this.errorCode});

  final String operationId;

  /// `null` cuando el servidor no conoce todavía esa operación.
  final SyncOperationStatus? status;
  final String? errorCode;

  bool get isUnknown => status == null;
}

/// Llamadas al backend para registrar una papeleta.
///
/// El dispositivo nunca envía su identificador: el servidor lo deriva de la
/// sesión. Aquí solo viajan la operación (idempotencia), la referencia opaca del
/// votante y la opción elegida.
abstract interface class BallotCastApi {
  Future<CastBallotResult> castBallot({
    required String operationId,
    required String voterRef,
    required BallotOption option,
    required String ballotId,
  });

  /// Recuperación ante respuestas perdidas: se consulta el estado real antes de
  /// reenviar, para no asumir fallo ni duplicar.
  Future<OperationStatus> getOperationStatus(String operationId);
}

class BallotGateway implements BallotCastApi {
  BallotGateway(this._client);

  final SupabaseClient _client;

  static const Set<String> _rejectionCodes = {
    'device_not_authorized',
    'device_not_assigned',
    'not_allowed',
    'not_authenticated',
  };

  @override
  Future<CastBallotResult> castBallot({
    required String operationId,
    required String voterRef,
    required BallotOption option,
    required String ballotId,
  }) async {
    if (_client.auth.currentSession == null) {
      throw const BallotRejectionException('not_authenticated');
    }

    final dynamic data;
    try {
      data = await _client.rpc(
        ElectoralRpc.castBallot,
        params: {
          'p_operation_id': operationId,
          'p_voter_ref': voterRef,
          'p_option_type': option.type.dbValue,
          'p_candidate_list_id': option.candidateListId,
          'p_ballot_id': ballotId,
        },
      );
    } on PostgrestException catch (error) {
      throw _classify(error.message.trim());
    } catch (_) {
      throw const BallotNetworkException();
    }

    if (data is! Map) {
      throw const BallotNetworkException('unexpected_response');
    }
    return CastBallotResult.fromJson(Map<String, Object?>.from(data));
  }

  /// Recuperación ante respuestas perdidas: se consulta el estado real antes de
  /// reenviar, para no asumir fallo ni duplicar.
  @override
  Future<OperationStatus> getOperationStatus(String operationId) async {
    if (_client.auth.currentSession == null) {
      throw const BallotRejectionException('not_authenticated');
    }

    final dynamic data;
    try {
      data = await _client.rpc(
        ElectoralRpc.getOperationStatus,
        params: {'p_operation_id': operationId},
      );
    } on PostgrestException catch (error) {
      throw _classify(error.message.trim());
    } catch (_) {
      throw const BallotNetworkException();
    }

    if (data is! Map) {
      throw const BallotNetworkException('unexpected_response');
    }
    final map = Map<String, Object?>.from(data);
    final raw = map['status']?.toString();
    if (raw == null || raw == 'unknown') {
      return OperationStatus(operationId, null);
    }
    return OperationStatus(
      operationId,
      SyncOperationStatus.fromDb(raw),
      errorCode: map['error_code'] as String?,
    );
  }

  Exception _classify(String message) => _rejectionCodes.contains(message)
      ? BallotRejectionException(message)
      : const BallotNetworkException('server_error');
}
