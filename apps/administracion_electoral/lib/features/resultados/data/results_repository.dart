import 'package:supabase_flutter/supabase_flutter.dart';

/// Fila agregada de la vista `election_results` (sin identidad del votante).
class ResultRow {
  const ResultRow({
    required this.optionType,
    required this.total,
    this.candidateListId,
  });

  final String optionType;
  final String? candidateListId;
  final int total;

  factory ResultRow.fromMap(Map<String, Object?> map) => ResultRow(
    optionType: map['option_type'] as String,
    candidateListId: map['candidate_list_id'] as String?,
    total: (map['total'] as num).toInt(),
  );
}

/// Totales desglosados de una elección ya cerrada.
class ElectionTotals {
  const ElectionTotals({
    required this.byList,
    required this.blank,
    required this.nullVotes,
  });

  final Map<String, int> byList;
  final int blank;
  final int nullVotes;

  int get validVotes => byList.values.fold(0, (sum, value) => sum + value);
  int get cast => validVotes + blank + nullVotes;
}

class ResultsRepository {
  ResultsRepository(this._client);

  final SupabaseClient _client;

  Future<ElectionTotals> loadTotals(String electionId) async {
    final rows = await _client
        .from('election_results')
        .select('option_type, candidate_list_id, total')
        .eq('election_id', electionId);
    final results = rows.map(ResultRow.fromMap);
    final byList = <String, int>{};
    var blank = 0;
    var nullVotes = 0;
    for (final row in results) {
      switch (row.optionType) {
        case 'list':
          final id = row.candidateListId;
          if (id != null) byList[id] = (byList[id] ?? 0) + row.total;
        case 'blank':
          blank += row.total;
        case 'null':
          nullVotes += row.total;
      }
    }
    return ElectionTotals(byList: byList, blank: blank, nullVotes: nullVotes);
  }
}
