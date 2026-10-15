import '../../core/offline/app_database.dart';

/// Oferta electoral descargada, agrupada para la papeleta.
class BallotCatalog {
  const BallotCatalog({required this.lists, required this.candidates});

  final List<LocalList> lists;
  final List<LocalCandidate> candidates;

  /// Integrantes de una lista, en el orden descargado.
  List<LocalCandidate> candidatesOf(String listId) =>
      [for (final c in candidates) if (c.listId == listId) c];

  bool get isEmpty => lists.isEmpty;
}
