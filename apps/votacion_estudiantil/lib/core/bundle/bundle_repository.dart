import 'package:electoral_core/electoral_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Error al descargar la configuración/padrón del dispositivo.
class BundleException implements Exception {
  const BundleException(this.code);

  final String code;

  String get message => switch (code) {
    'device_not_authorized' =>
      'Este equipo ya no está autorizado. Vuelve a vincularlo o pide al '
          'personal electoral que lo habilite.',
    'device_not_assigned' =>
      'El dispositivo no tiene una elección asignada todavía.',
    'election_not_found' =>
      'La elección asignada ya no existe. Consulta con el personal.',
    'not_authenticated' =>
      'La sesión del dispositivo expiró. Vuelve a vincularlo.',
    'network' => 'No se pudo conectar con el servidor. Revisa la red.',
    _ => 'No se pudo descargar la configuración ($code). Intenta de nuevo.',
  };

  @override
  String toString() => 'BundleException($code)';
}

/// Descarga el paquete del dispositivo (`get_device_bundle`) desde el backend.
///
/// El servidor deriva el dispositivo de la sesión; aquí no se envía ningún id.
class BundleRepository {
  BundleRepository(this._client);

  final SupabaseClient _client;

  static const Set<String> _knownCodes = {
    'device_not_authorized',
    'device_not_assigned',
    'election_not_found',
  };

  Future<DeviceBundle> fetch() async {
    if (_client.auth.currentSession == null) {
      throw const BundleException('not_authenticated');
    }

    final dynamic data;
    try {
      data = await _client.rpc(ElectoralRpc.getDeviceBundle);
    } on PostgrestException catch (error) {
      final message = error.message.trim();
      throw BundleException(
        _knownCodes.contains(message) ? message : 'server_error',
      );
    } catch (_) {
      throw const BundleException('network');
    }

    if (data is! Map) {
      throw const BundleException('unexpected_response');
    }
    return DeviceBundle.fromJson(Map<String, Object?>.from(data));
  }
}
