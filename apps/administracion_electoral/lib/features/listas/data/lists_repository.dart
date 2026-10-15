import 'package:supabase_flutter/supabase_flutter.dart';

/// Lista electoral: cantidad variable por elección.
class CandidateList {
  const CandidateList({
    required this.id,
    required this.electionId,
    required this.number,
    required this.name,
    required this.enabled,
    this.slogan,
    this.emblemPath,
  });

  final String id;
  final String electionId;
  final int number;
  final String name;
  final String? slogan;
  final String? emblemPath;
  final bool enabled;

  factory CandidateList.fromMap(Map<String, Object?> map) => CandidateList(
    id: map['id'] as String,
    electionId: map['election_id'] as String,
    number: (map['number'] as num).toInt(),
    name: map['name'] as String,
    slogan: map['slogan'] as String?,
    emblemPath: map['emblem_path'] as String?,
    enabled: map['enabled'] as bool,
  );
}

/// Candidato dentro de una lista.
class CandidateItem {
  const CandidateItem({
    required this.id,
    required this.listId,
    required this.fullName,
    required this.position,
    required this.orderIndex,
  });

  final String id;
  final String listId;
  final String fullName;
  final String position;
  final int orderIndex;

  factory CandidateItem.fromMap(Map<String, Object?> map) => CandidateItem(
    id: map['id'] as String,
    listId: map['list_id'] as String,
    fullName: map['full_name'] as String,
    position: map['position'] as String,
    orderIndex: (map['order_index'] as num).toInt(),
  );
}

class ListsRepository {
  ListsRepository(this._client);

  final SupabaseClient _client;

  Future<List<CandidateList>> listLists(String electionId) async {
    final rows = await _client
        .from('candidate_lists')
        .select('id, election_id, number, name, slogan, emblem_path, enabled')
        .eq('election_id', electionId)
        .order('number');
    return rows.map(CandidateList.fromMap).toList();
  }

  Future<void> createList({
    required String electionId,
    required int number,
    required String name,
    String? slogan,
    String? emblemPath,
  }) async {
    await _client.from('candidate_lists').insert({
      'election_id': electionId,
      'number': number,
      'name': name,
      'slogan': _blankToNull(slogan),
      'emblem_path': _blankToNull(emblemPath),
    });
  }

  Future<void> updateList(
    String id, {
    required int number,
    required String name,
    String? slogan,
    String? emblemPath,
  }) async {
    await _client.from('candidate_lists').update({
      'number': number,
      'name': name,
      'slogan': _blankToNull(slogan),
      'emblem_path': _blankToNull(emblemPath),
    }).eq('id', id);
  }

  Future<void> setListEnabled(String id, bool enabled) async {
    await _client.from('candidate_lists').update({'enabled': enabled}).eq('id', id);
  }

  Future<void> deleteList(String id) async {
    await _client.from('candidate_lists').delete().eq('id', id);
  }

  Future<List<CandidateItem>> listCandidates(String listId) async {
    final rows = await _client
        .from('candidates')
        .select('id, list_id, full_name, position, order_index')
        .eq('list_id', listId)
        .order('order_index');
    return rows.map(CandidateItem.fromMap).toList();
  }

  Future<void> createCandidate({
    required String listId,
    required String fullName,
    required String position,
    int orderIndex = 0,
  }) async {
    await _client.from('candidates').insert({
      'list_id': listId,
      'full_name': fullName,
      'position': position,
      'order_index': orderIndex,
    });
  }

  Future<void> updateCandidate(
    String id, {
    required String fullName,
    required String position,
    int orderIndex = 0,
  }) async {
    await _client.from('candidates').update({
      'full_name': fullName,
      'position': position,
      'order_index': orderIndex,
    }).eq('id', id);
  }

  Future<void> deleteCandidate(String id) async {
    await _client.from('candidates').delete().eq('id', id);
  }

  static String? _blankToNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}