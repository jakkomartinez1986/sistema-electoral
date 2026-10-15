/// Validación del número de cédula ecuatoriana.
///
/// Reglas aplicadas (persona natural):
///  * 10 dígitos numéricos.
///  * Los dos primeros dígitos son la provincia (01–24, más el 30 para
///    ecuatorianos en el exterior).
///  * El tercer dígito debe ser menor que 6.
///  * Dígito verificador por módulo 10 (algoritmo oficial del Registro Civil).
///
/// Esto valida el *formato* de la cédula, no que exista ni que pertenezca a
/// una persona concreta. La identidad se comprueba contra el padrón.
class CedulaEcuador {
  const CedulaEcuador._();

  static final RegExp _digits = RegExp(r'^\d{10}$');

  /// Normaliza quitando espacios y guiones; devuelve `null` si queda inválida.
  static String? normalize(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[\s-]'), '');
    return isValid(cleaned) ? cleaned : null;
  }

  static bool isValid(String value) {
    if (!_digits.hasMatch(value)) return false;

    final province = int.parse(value.substring(0, 2));
    if (province < 1 || (province > 24 && province != 30)) return false;

    if (int.parse(value[2]) >= 6) return false;

    const weights = [2, 1, 2, 1, 2, 1, 2, 1, 2];
    var sum = 0;
    for (var i = 0; i < 9; i++) {
      var product = int.parse(value[i]) * weights[i];
      if (product >= 10) product -= 9;
      sum += product;
    }

    final checkDigit = (10 - (sum % 10)) % 10;
    return checkDigit == int.parse(value[9]);
  }
}
