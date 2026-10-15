import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Cálculo del verificador opaco del padrón.
///
/// El servidor ya no envía la cédula ni el PIN en claro: envía un verificador
/// con la forma
///
///     sha256( salt || ':' || tipo || ':' || secreto_normalizado )
///
/// con `salt = institutions.id`. Este helper reproduce ese cálculo para que el
/// dispositivo pueda comprobar, **sin conexión**, lo que digita el estudiante.
///
/// La cédula se normaliza quitando espacios y guiones; debe coincidir con la
/// forma almacenada en el servidor (solo dígitos).
abstract final class PadronVerifier {
  const PadronVerifier._();

  static const String cedulaKind = 'cedula';
  static const String pinKind = 'pin';

  /// Verificador genérico. [secret] se recorta; para cédulas usa [cedula].
  static String compute({
    required String salt,
    required String kind,
    required String secret,
  }) {
    final payload = '$salt:$kind:${secret.trim()}';
    return sha256.convert(utf8.encode(payload)).toString();
  }

  /// Verificador de cédula (normalizada a dígitos).
  static String cedula({required String salt, required String cedula}) =>
      compute(salt: salt, kind: cedulaKind, secret: normalizeCedula(cedula));

  /// Verificador de PIN.
  static String pin({required String salt, required String pin}) =>
      compute(salt: salt, kind: pinKind, secret: pin);

  /// Deja solo los dígitos de la cédula (quita espacios, guiones y puntos).
  static String normalizeCedula(String raw) =>
      raw.replaceAll(RegExp(r'[^0-9]'), '');
}
