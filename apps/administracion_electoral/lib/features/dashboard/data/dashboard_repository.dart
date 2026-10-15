import 'package:supabase_flutter/supabase_flutter.dart';

/// Contadores estructurales que alimentan el panel del administrador.
///
/// No incluye votos ni participación: esas cifras no se muestran mientras la
/// elección esté abierta.
class DashboardCounts {
  const DashboardCounts({
    required this.elections,
    required this.courses,
    required this.enabledStudents,
    required this.candidateLists,
    required this.authorizedDevices,
    required this.pendingDevices,
  });

  final int elections;
  final int courses;
  final int enabledStudents;
  final int candidateLists;
  final int authorizedDevices;
  final int pendingDevices;

  static const DashboardCounts empty = DashboardCounts(
    elections: 0,
    courses: 0,
    enabledStudents: 0,
    candidateLists: 0,
    authorizedDevices: 0,
    pendingDevices: 0,
  );
}

/// Lee los contadores respetando RLS (cada consulta ve solo lo que el rol permite).
class DashboardRepository {
  DashboardRepository(this._client);

  final SupabaseClient _client;

  Future<DashboardCounts> loadCounts() async {
    final elections = await _client.from('elections').count();
    final courses = await _client.from('courses').count();
    final lists = await _client.from('candidate_lists').count();
    final students =
        await _countWhere('students', 'enabled', true);
    final authorized =
        await _countWhere('voting_devices', 'status', 'authorized');
    final pending = await _countWhere('voting_devices', 'status', 'pending');

    return DashboardCounts(
      elections: elections,
      courses: courses,
      enabledStudents: students,
      candidateLists: lists,
      authorizedDevices: authorized,
      pendingDevices: pending,
    );
  }

  Future<int> _countWhere(String table, String column, Object value) async {
    final response =
        await _client.from(table).select('id').eq(column, value).count();
    return response.count;
  }
}
