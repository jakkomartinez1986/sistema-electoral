import 'package:electoral_core/electoral_core.dart';

/// Configuración de la aplicación de votación.
///
/// Igual que en administración: se puede inyectar con `--dart-define`; los
/// valores por defecto existen para que `flutter run` funcione sin banderas. La
/// clave es **publicable** (segura en el cliente porque RLS decide qué se ve).
const SupabaseConfig kAppSupabaseConfig = SupabaseConfig(
  url: String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://kxaizzbbntdzrzywpzyv.supabase.co',
  ),
  publishableKey: String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_38b5HMfqGLDTm7pfXJwalQ_l0QUVGIm',
  ),
);
