import 'package:electoral_core/electoral_core.dart';

/// Configuración de la aplicación.
///
/// Los valores se pueden inyectar en compilación con `--dart-define` (ver
/// `docs/instalacion.md`); los de aquí son solo valores por defecto para que
/// `flutter run` funcione sin banderas. La clave es **publicable** (segura en el
/// cliente porque RLS decide qué se ve), nunca la secret key.
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
