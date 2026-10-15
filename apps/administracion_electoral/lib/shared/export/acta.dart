/// Datos congelados para generar el acta de resultados.
///
/// No contiene identidad del votante: solo agregados (por lista, blancos y
/// nulos) y la participación. Es un objeto puro para poder probarlo sin red ni
/// Supabase.
class ActaListRow {
  const ActaListRow({
    required this.number,
    required this.name,
    required this.votes,
  });

  final int number;
  final String name;
  final int votes;
}

class ActaData {
  const ActaData({
    required this.institutionName,
    required this.electionName,
    required this.statusLabel,
    required this.generatedAt,
    required this.lists,
    required this.blank,
    required this.nullVotes,
    this.closedAt,
    this.participation,
    this.issued,
  });

  final String institutionName;
  final String electionName;
  final String statusLabel;
  final DateTime generatedAt;
  final List<ActaListRow> lists;
  final int blank;
  final int nullVotes;
  final DateTime? closedAt;
  final int? participation;
  final int? issued;

  int get validVotes => lists.fold(0, (sum, row) => sum + row.votes);
  int get cast => validVotes + blank + nullVotes;

  /// Listas ordenadas de mayor a menor número de votos (empate: por número).
  List<ActaListRow> get orderedByVotes {
    final ordered = [...lists];
    ordered.sort((a, b) {
      final byVotes = b.votes.compareTo(a.votes);
      return byVotes != 0 ? byVotes : a.number.compareTo(b.number);
    });
    return ordered;
  }
}
