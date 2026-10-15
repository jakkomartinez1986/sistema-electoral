import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bundle/bundle_repository.dart';
import 'bundle/bundle_verifier.dart';
import 'bundle/provisioning_repository.dart';
import 'device/device_identity.dart';
import 'enrollment/enrollment_repository.dart';
import 'offline/app_database.dart';

/// Cliente de Supabase compartido. Requiere [initSupabase] previo (`main.dart`).
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

/// Base de datos local (drift) para el funcionamiento offline-first.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

/// Identificador estable del dispositivo (se crea una vez y se persiste).
final deviceUidProvider = FutureProvider<String>(
  (ref) => DeviceIdentity.loadOrCreate().then((identity) => identity.uid),
);

final enrollmentRepositoryProvider = Provider<EnrollmentRepository>(
  (ref) => EnrollmentRepository(ref.watch(supabaseClientProvider)),
);

final bundleRepositoryProvider = Provider<BundleRepository>(
  (ref) => BundleRepository(ref.watch(supabaseClientProvider)),
);

final provisioningRepositoryProvider = Provider<ProvisioningRepository>(
  (ref) => ProvisioningRepository(ref.watch(appDatabaseProvider)),
);

/// Configuración local activa (o `null` si aún no se ha descargado).
final localConfigProvider = StreamProvider<LocalConfigData?>(
  (ref) => ref.watch(provisioningRepositoryProvider).watchConfig(),
);

/// Sesión de Auth del dispositivo: permite saber si ya está vinculado.
final authSessionProvider = StreamProvider<Session?>((ref) async* {
  final auth = ref.watch(supabaseClientProvider).auth;
  yield auth.currentSession;
  yield* auth.onAuthStateChange.map((event) => event.session);
});

/// Estado del enrolamiento disparado desde la pantalla de configuración.
class EnrollmentController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> enroll(String code) async {
    final uid = await ref.read(deviceUidProvider.future);
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(enrollmentRepositoryProvider)
          .enroll(code: code, deviceUid: uid),
    );
  }

  void reset() => state = const AsyncData(null);
}

final enrollmentControllerProvider =
    AsyncNotifierProvider<EnrollmentController, void>(
      EnrollmentController.new,
    );

/// Descarga y verificación del paquete del dispositivo (config + padrón).
class ProvisioningController extends AsyncNotifier<ProvisioningReport?> {
  @override
  Future<ProvisioningReport?> build() async => null;

  Future<void> download() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final bundle = await ref.read(bundleRepositoryProvider).fetch();
      final report = verifyBundle(bundle);
      await ref.read(provisioningRepositoryProvider).applyBundle(bundle);
      return report;
    });
  }
}

final provisioningControllerProvider =
    AsyncNotifierProvider<ProvisioningController, ProvisioningReport?>(
      ProvisioningController.new,
    );
