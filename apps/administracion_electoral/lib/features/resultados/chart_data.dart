/// Reparto de votos para los gráficos de resultados.
///
/// Objeto puro (sin red ni Supabase) para poder probarlo: recibe las listas ya
/// ordenadas con sus votos y agrega en blanco y nulos como categorías. Los
/// gráficos (dona y barras) se construyen a partir de esta lista.
class VoteCount {
  const VoteCount({required this.label, required this.votes, this.isList = true});

  final String label;
  final int votes;

  /// `true` para listas; `false` para en blanco/nulos (se pintan en gris).
  final bool isList;
}

/// Construye el reparto de votos. Las categorías en blanco y nulos solo se
/// incluyen si tienen votos (evita barras y porciones en cero).
List<VoteCount> voteDistribution({
  required List<VoteCount> lists,
  required int blank,
  required int nullVotes,
}) => [
  ...lists,
  if (blank > 0) VoteCount(label: 'En blanco', votes: blank, isList: false),
  if (nullVotes > 0)
    VoteCount(label: 'Nulos', votes: nullVotes, isList: false),
];
