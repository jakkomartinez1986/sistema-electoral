/// Validación del código estudiantil interno.
///
/// El código es un identificador estable, no un dato personal sensible. Cada
/// institución decide su formato; [StudentCodeRules] permite configurarlo sin
/// recompilar la lógica.
class StudentCodeRules {
  const StudentCodeRules({
    this.minLength = 3,
    this.maxLength = 20,
    this.pattern,
  });

  final int minLength;
  final int maxLength;

  /// Patrón opcional (p. ej. `^[A-Z]{2}\d{5}$`). Si es `null` se aceptan
  /// letras, dígitos, guion y guion bajo.
  final RegExp? pattern;

  static final RegExp _default = RegExp(r'^[A-Za-z0-9_-]+$');

  /// Reglas por defecto: 3–20 caracteres alfanuméricos sin espacios.
  static const StudentCodeRules defaults = StudentCodeRules();

  String? validate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return 'El código es obligatorio';
    if (value.length < minLength) {
      return 'El código debe tener al menos $minLength caracteres';
    }
    if (value.length > maxLength) {
      return 'El código debe tener como máximo $maxLength caracteres';
    }
    final regex = pattern ?? _default;
    if (!regex.hasMatch(value)) {
      return 'El código contiene caracteres no permitidos';
    }
    return null;
  }

  bool isValid(String raw) => validate(raw) == null;
}
