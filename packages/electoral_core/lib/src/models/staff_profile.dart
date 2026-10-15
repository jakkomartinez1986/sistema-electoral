import '../constants.dart';

/// Perfil del personal autenticado (administración).
///
/// Reúne la fila de `user_profiles` y sus roles de `user_roles`. El rol efectivo
/// siempre lo decide el servidor; aquí solo se refleja para la interfaz.
class StaffProfile {
  const StaffProfile({
    required this.id,
    required this.fullName,
    required this.roles,
    this.email,
    this.institutionId,
  });

  /// Mismo `id` que `auth.users`.
  final String id;
  final String fullName;
  final String? email;
  final String? institutionId;

  /// Roles asignados (puede estar vacío si el usuario no tiene ninguno).
  final Set<UserRole> roles;

  bool get isAdmin => roles.contains(UserRole.admin);
  bool get isOperator => roles.contains(UserRole.operator);
  bool get isTutor => roles.contains(UserRole.tutor);

  /// ¿Tiene algún rol operativo? Un usuario sin rol no debe operar.
  bool get isStaff => roles.isNotEmpty;

  factory StaffProfile.fromJson(Map<String, Object?> json) {
    final raw = (json['roles'] as List?) ?? const <Object?>[];
    final roles = <UserRole>{};
    for (final entry in raw) {
      if (entry is String) {
        roles.add(UserRole.fromDb(entry));
      } else if (entry is Map && entry['role'] is String) {
        roles.add(UserRole.fromDb(entry['role'] as String));
      }
    }
    return StaffProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String?,
      institutionId: json['institution_id'] as String?,
      roles: roles,
    );
  }
}
