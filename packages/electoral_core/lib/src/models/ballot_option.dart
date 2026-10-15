import '../constants.dart';

/// Opción depositada en una papeleta, lista para enviarse al servidor.
///
/// Es un modelo de transporte: no contiene el identificador del estudiante, ni
/// tampoco un identificador de participación. La separación entre quién votó y
/// qué eligió se garantiza en el backend; aquí solo se evita arrastrar
/// identidad hacia la papeleta.
class BallotOption {
  const BallotOption._(this.type, this.candidateListId);

  /// Voto por una lista habilitada.
  const BallotOption.list(String candidateListId)
      : this._(BallotOptionType.candidateList, candidateListId);

  /// Voto en blanco.
  const BallotOption.blank() : this._(BallotOptionType.blank, null);

  /// Voto nulo.
  const BallotOption.nullVote() : this._(BallotOptionType.nullVote, null);

  final BallotOptionType type;
  final String? candidateListId;

  static BallotOption fromDb({
    required String optionType,
    String? candidateListId,
  }) {
    final type = BallotOptionType.fromDb(optionType);
    if (type == BallotOptionType.candidateList) {
      if (candidateListId == null || candidateListId.isEmpty) {
        throw ArgumentError('Una papeleta de lista requiere candidateListId');
      }
      return BallotOption.list(candidateListId);
    }
    return type == BallotOptionType.blank
        ? const BallotOption.blank()
        : const BallotOption.nullVote();
  }

  /// Carga útil para el RPC `cast_ballot`. Nunca incluye identidad del votante.
  Map<String, Object?> toPayload() => {
        'option_type': type.dbValue,
        'candidate_list_id': candidateListId,
      };

  @override
  bool operator ==(Object other) =>
      other is BallotOption &&
      other.type == type &&
      other.candidateListId == candidateListId;

  @override
  int get hashCode => Object.hash(type, candidateListId);

  @override
  String toString() => candidateListId == null
      ? 'BallotOption(${type.dbValue})'
      : 'BallotOption(${type.dbValue}, $candidateListId)';
}
