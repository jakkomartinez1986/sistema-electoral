import 'cedula_ecuador.dart';
import 'padron_verifier.dart';

/// Entrada mínima del padrón local necesaria para identificar a un votante.
///
/// Es una vista reducida del `local_voters` de cada app: solo la referencia
/// opaca y los verificadores. No incluye nombres ni datos personales en claro.
class PadronEntry {
  const PadronEntry({
    required this.voterRef,
    required this.code,
    this.cedulaVerifier,
    this.pinVerifier,
  });

  /// Referencia opaca que viaja a la papeleta.
  final String voterRef;

  /// Código estudiantil interno (identifica, no es secreto sensible).
  final String code;

  /// Verificador derivado de la cédula; `null` si el estudiante no tiene.
  final String? cedulaVerifier;

  /// Verificador derivado del PIN; `null` si no se configuró.
  final String? pinVerifier;

  /// Ni cédula ni PIN: solo se puede identificar por código.
  bool get isCodeOnly => cedulaVerifier == null && pinVerifier == null;

  /// Normaliza el código para comparar (sin espacios, en mayúsculas).
  static String normalizeCode(String raw) => raw.trim().toUpperCase();
}

/// Resultado de la identificación contra el padrón local.
enum VoterMatchStatus {
  /// Se encontró al votante y sus credenciales coinciden.
  found,

  /// No hay ningún votante con esas credenciales en el padrón.
  notFound,

  /// El código existe pero el PIN no coincide.
  badPin,

  /// La cédula no tiene un formato válido (módulo 10).
  invalidCedula,

  /// El código estudiantil está vacío.
  invalidCode,
}

/// Resultado de [VoterLookup]: estado y, si aplica, la referencia encontrada.
class VoterMatchResult {
  const VoterMatchResult(this.status, {this.voterRef});

  final VoterMatchStatus status;
  final String? voterRef;

  bool get found => status == VoterMatchStatus.found;

  static const VoterMatchResult notFound = VoterMatchResult(
    VoterMatchStatus.notFound,
  );

  @override
  String toString() => 'VoterMatchResult(${status.name}'
      '${voterRef == null ? '' : ', $voterRef'})';
}

/// Identificación **sin conexión** de un votante en el padrón descargado.
///
/// Reproduce en el cliente la misma comparación de verificadores que hace el
/// servidor (`sha256(salt || ':' || tipo || ':' || secreto)`), de modo que la
/// identidad nunca viaja ni se guarda en claro. La decisión final de aceptar el
/// voto sigue siendo del servidor (`cast_ballot`); aquí solo se evita habilitar
/// una papeleta para alguien que no pertenece al padrón del equipo.
abstract final class VoterLookup {
  const VoterLookup._();

  /// Identifica por **cédula ecuatoriana** (se normaliza y valida el formato).
  static VoterMatchResult byCedula({
    required String salt,
    required String cedula,
    required List<PadronEntry> padron,
  }) {
    final normalized = CedulaEcuador.normalize(cedula);
    if (normalized == null) {
      return const VoterMatchResult(VoterMatchStatus.invalidCedula);
    }
    final verifier = PadronVerifier.cedula(salt: salt, cedula: normalized);
    for (final entry in padron) {
      if (entry.cedulaVerifier == verifier) {
        return VoterMatchResult(
          VoterMatchStatus.found,
          voterRef: entry.voterRef,
        );
      }
    }
    return VoterMatchResult.notFound;
  }

  /// Identifica por **código estudiantil + PIN**.
  ///
  /// Si el votante no tiene PIN configurado ([PadronEntry.isCodeOnly]) basta el
  /// código; el PIN se exige y se comprueba cuando el padrón trae verificador.
  static VoterMatchResult byCode({
    required String salt,
    required String code,
    required String pin,
    required List<PadronEntry> padron,
  }) {
    final normalized = PadronEntry.normalizeCode(code);
    if (normalized.isEmpty) {
      return const VoterMatchResult(VoterMatchStatus.invalidCode);
    }

    PadronEntry? match;
    for (final entry in padron) {
      if (PadronEntry.normalizeCode(entry.code) == normalized) {
        match = entry;
        break;
      }
    }
    if (match == null) return VoterMatchResult.notFound;

    final pinVerifier = match.pinVerifier;
    if (pinVerifier != null) {
      final secret = pin.trim();
      if (secret.isEmpty ||
          PadronVerifier.pin(salt: salt, pin: secret) != pinVerifier) {
        return const VoterMatchResult(VoterMatchStatus.badPin);
      }
    }

    return VoterMatchResult(VoterMatchStatus.found, voterRef: match.voterRef);
  }
}
