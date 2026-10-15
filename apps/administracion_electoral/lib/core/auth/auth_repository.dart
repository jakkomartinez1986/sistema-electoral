import 'package:electoral_core/electoral_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Acceso a la sesión del personal y a su perfil.
///
/// El backend resuelve el rol a partir de `auth.uid()`; aquí solo se lee lo que
/// RLS permite ver al propio usuario.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  /// ¿Hay una sesión activa en este momento?
  bool get hasSession => _client.auth.currentSession != null;

  /// Inicia sesión con email y contraseña (personal electoral).
  Future<void> signIn({required String email, required String password}) {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Cierra la sesión local y revoca el token en el servidor.
  Future<void> signOut() => _client.auth.signOut();

  /// Carga el perfil del usuario autenticado junto con sus roles.
  ///
  /// Devuelve `null` cuando no hay sesión o cuando el usuario todavía no tiene
  /// fila en `user_profiles` (no debería operar en ese caso).
  Future<StaffProfile?> loadStaffProfile() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await _client
        .from('user_profiles')
        .select('id, full_name, email, institution_id, roles:user_roles(role)')
        .eq('id', uid)
        .maybeSingle();
    if (row == null) return null;
    return StaffProfile.fromJson(row);
  }
}
