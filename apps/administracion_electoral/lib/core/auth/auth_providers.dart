import 'package:electoral_core/electoral_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/supabase_providers.dart';
import 'auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);

/// Sesión del personal: expone el perfil autenticado o `null`.
///
/// Se mantiene sincronizado con el ciclo de vida de Auth de Supabase, de modo
/// que un cierre de sesión (o una expiración) empuja al usuario a la pantalla de
/// acceso.
class AuthController extends AsyncNotifier<StaffProfile?> {
  @override
  Future<StaffProfile?> build() async {
    final client = ref.watch(supabaseClientProvider);
    var disposed = false;
    ref.onDispose(() => disposed = true);
    final sub = client.auth.onAuthStateChange.listen((_) async {
      final next = await AsyncValue.guard(_resolveProfile);
      if (disposed) return;
      state = next;
    });
    ref.onDispose(sub.cancel);
    return _resolveProfile();
  }

  Future<StaffProfile?> _resolveProfile() =>
      ref.read(authRepositoryProvider).loadStaffProfile();

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signIn(
            email: email,
            password: password,
          );
      return _resolveProfile();
    });
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncValue.data(null);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, StaffProfile?>(AuthController.new);

/// Institución del perfil autenticado (`null` mientras no se resuelve).
final currentInstitutionIdProvider = Provider<String?>(
  (ref) => ref.watch(authControllerProvider).value?.institutionId,
);
