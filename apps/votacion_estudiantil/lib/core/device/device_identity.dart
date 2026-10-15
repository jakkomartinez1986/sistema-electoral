import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Identificador estable del dispositivo.
///
/// El servidor exige que el `device_uid` que envía el dispositivo coincida con
/// el registrado por el administrador. Por eso se genera una vez, se persiste y
/// se muestra en pantalla para que el personal lo registre. No es un secreto:
/// la seguridad del emparejamiento recae en el código de un solo uso.
class DeviceIdentity {
  DeviceIdentity._(this.uid);

  final String uid;

  static const String _key = 'device_uid';

  static Future<DeviceIdentity> loadOrCreate() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_key);
    if (existing != null && existing.isNotEmpty) {
      return DeviceIdentity._(existing);
    }
    final generated = _generate();
    await prefs.setString(_key, generated);
    return DeviceIdentity._(generated);
  }

  static String _generate() {
    const hex = '0123456789ABCDEF';
    final random = Random.secure();
    final buffer = StringBuffer('DEV-');
    for (var i = 0; i < 12; i++) {
      buffer.write(hex[random.nextInt(hex.length)]);
    }
    return buffer.toString();
  }
}
