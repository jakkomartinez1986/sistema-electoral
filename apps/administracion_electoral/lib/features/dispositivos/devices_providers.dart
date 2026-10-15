import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/data/supabase_providers.dart';
import 'data/devices_repository.dart';

final devicesRepositoryProvider = Provider<DevicesRepository>(
  (ref) => DevicesRepository(ref.watch(supabaseClientProvider)),
);

final devicesProvider = FutureProvider<List<VotingDevice>>((ref) {
  final id = ref.watch(currentInstitutionIdProvider);
  if (id == null) return Future<List<VotingDevice>>.value(const <VotingDevice>[]);
  return ref.watch(devicesRepositoryProvider).listDevices(id);
});

final deviceAssignmentsProvider =
    FutureProvider.family<List<DeviceAssignment>, String>(
      (ref, deviceId) =>
          ref.watch(devicesRepositoryProvider).listAssignments(deviceId),
    );