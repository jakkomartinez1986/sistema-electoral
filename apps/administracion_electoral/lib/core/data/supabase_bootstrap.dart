import 'package:electoral_core/electoral_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Inicializa el cliente de Supabase antes de levantar la interfaz.
///
/// Se llama una sola vez en `main`. El cliente solo usa la clave pública; RLS
/// decide qué puede ver y hacer cada sesión.
Future<void> initSupabase(SupabaseConfig config) async {
  await Supabase.initialize(
    url: config.url,
    publishableKey: config.publishableKey,
  );
}
