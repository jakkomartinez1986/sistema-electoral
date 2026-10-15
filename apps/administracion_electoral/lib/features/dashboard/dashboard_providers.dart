import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/supabase_providers.dart';
import 'data/dashboard_repository.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(ref.watch(supabaseClientProvider)),
);

/// Contadores del panel, cargados desde el backend y filtrados por RLS.
final dashboardCountsProvider = FutureProvider<DashboardCounts>(
  (ref) => ref.watch(dashboardRepositoryProvider).loadCounts(),
);
