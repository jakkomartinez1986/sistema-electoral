import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/data/supabase_providers.dart';
import 'data/archive_repository.dart';

final archiveRepositoryProvider = Provider<ArchiveRepository>(
  (ref) => ArchiveRepository(ref.watch(supabaseClientProvider)),
);

final auditLogsProvider = FutureProvider<List<AuditEntry>>((ref) {
  final id = ref.watch(currentInstitutionIdProvider);
  if (id == null) return Future<List<AuditEntry>>.value(const <AuditEntry>[]);
  return ref.watch(archiveRepositoryProvider).listAuditLogs(id);
});
