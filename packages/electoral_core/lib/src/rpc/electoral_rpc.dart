/// Nombres de las funciones RPC expuestas por el backend.
///
/// Se centralizan para que cliente y servidor no diverjan por un `string`
/// mal escrito. Los contratos están en `docs/backend_rpc.md`.
abstract final class ElectoralRpc {
  /// Registra participación + papeleta en una transacción (solo dispositivo).
  static const String castBallot = 'cast_ballot';

  /// Recupera el estado de una operación propia (idempotencia / reintentos).
  static const String getOperationStatus = 'get_operation_status';

  /// Cambia el estado de una elección (solo `admin`).
  static const String transitionElection = 'transition_election';

  /// Genera y versiona la configuración descargable de una elección.
  static const String generateElectionConfig = 'generate_election_config';

  /// Genera un código de emparejamiento de un solo uso (solo `admin`).
  static const String createEnrollmentCode = 'create_enrollment_code';

  /// Entrega al dispositivo su configuración y padrón (config + verificadores).
  static const String getDeviceBundle = 'get_device_bundle';

  /// Define o borra el PIN de votación de un estudiante (solo `staff`).
  static const String setStudentPin = 'set_student_pin';
}
