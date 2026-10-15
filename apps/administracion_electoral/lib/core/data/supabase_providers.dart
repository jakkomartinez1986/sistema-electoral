import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cliente de Supabase compartido por toda la aplicación.
///
/// Requiere que [initSupabase] se haya ejecutado antes (ver `main.dart`).
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);
