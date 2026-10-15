/// Configuración de acceso al backend Supabase.
///
/// Dart puro: el valor se inyecta en compilación con `--dart-define`, así que las
/// apps solo necesitan leerlo; nunca se guarda un secreto aquí. La clave pública
/// (`publishable`) es segura en el cliente porque RLS decide qué se ve.
library;

/// URL y clave pública del proyecto Supabase.
class SupabaseConfig {
  const SupabaseConfig({required this.url, required this.publishableKey});

  /// URL base del proyecto, p. ej. `https://xxxx.supabase.co`.
  final String url;

  /// Clave publicable (`sb_publishable_...` o la antigua `anon`).
  final String publishableKey;

  /// ¿Hay valores suficientes para intentar conectarse?
  bool get isConfigured => url.trim().isNotEmpty && publishableKey.trim().isNotEmpty;

  /// Valores inyectados con `--dart-define` en tiempo de compilación.
  ///
  /// ```powershell
  /// flutter run --dart-define=SUPABASE_URL=... `
  ///             --dart-define=SUPABASE_PUBLISHABLE_KEY=...
  /// ```
  static const SupabaseConfig fromEnvironment = SupabaseConfig(
    url: String.fromEnvironment('SUPABASE_URL'),
    publishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );

  @override
  String toString() =>
      'SupabaseConfig(url: $url, publishableKey: ${publishableKey.isEmpty ? '(vacía)' : '(definida)'})';
}
