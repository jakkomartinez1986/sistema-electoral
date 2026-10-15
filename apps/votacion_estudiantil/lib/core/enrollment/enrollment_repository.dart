import 'package:supabase_flutter/supabase_flutter.dart';

/// Versión que se reporta al servidor al enrolar (no es crítica).
const String kAppVersion = '0.1.0';

/// Error de enrolamiento con el código devuelto por la Edge Function.
class EnrollmentException implements Exception {
  const EnrollmentException(this.code);

  final String code;

  /// Mensaje para la persona que usa el dispositivo.
  String get message => switch (code) {
    'invalid_code' => 'El código no es válido. Revisa los caracteres.',
    'code_used' => 'Ese código ya se usó. Pide uno nuevo al personal.',
    'code_expired' => 'El código expiró. Pide uno nuevo al personal.',
    'device_mismatch' =>
      'Este equipo no coincide con el registrado para ese código. '
          'Registra el identificador que aparece abajo.',
    'device_not_found' => 'El dispositivo no está registrado.',
    'missing_fields' => 'Faltan datos para vincular el dispositivo.',
    'auth_user_creation_failed' =>
      'No se pudo crear la credencial del dispositivo. Intenta de nuevo.',
    'device_link_failed' =>
      'No se pudo vincular el dispositivo. Intenta de nuevo.',
    'session_grant_failed' =>
      'No se pudo iniciar la sesión del dispositivo. Intenta de nuevo.',
    'unexpected_response' =>
      'Respuesta inesperada del servidor. Intenta de nuevo.',
    _ => 'No se pudo vincular el dispositivo. Intenta de nuevo.',
  };

  @override
  String toString() => 'EnrollmentException($code)';
}

/// Resultado del enrolamiento exitoso.
class EnrolledDevice {
  const EnrolledDevice({required this.deviceId, required this.userId});

  final String deviceId;
  final String userId;
}

/// Canjea códigos de emparejamiento contra la Edge Function `enroll-device`.
class EnrollmentRepository {
  EnrollmentRepository(this._client);

  final SupabaseClient _client;

  Future<EnrolledDevice> enroll({
    required String code,
    required String deviceUid,
    String? appVersion,
  }) async {
    FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'enroll-device',
        body: {
          'enrollment_code': code.trim().toUpperCase(),
          'device_uid': deviceUid,
          'app_version': appVersion ?? kAppVersion,
        },
      );
    } on FunctionException catch (error) {
      final details = error.details;
      final code = details is Map && details['error'] != null
          ? details['error'].toString()
          : 'network';
      throw EnrollmentException(code);
    } catch (_) {
      throw const EnrollmentException('network');
    }

    final data = response.data;
    final error = data is Map ? data['error'] : null;
    if (error != null) {
      throw EnrollmentException(error.toString());
    }
    if (data is! Map || data['refresh_token'] == null) {
      throw const EnrollmentException('unexpected_response');
    }

    await _client.auth.setSession(data['refresh_token'] as String);

    return EnrolledDevice(
      deviceId: '${data['device_id']}',
      userId: '${data['user_id']}',
    );
  }
}
