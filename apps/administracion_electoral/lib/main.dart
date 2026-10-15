import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/data/supabase_bootstrap.dart';
import 'features/system/not_configured_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kAppSupabaseConfig.isConfigured) {
    runApp(const NotConfiguredApp());
    return;
  }

  await initSupabase(kAppSupabaseConfig);
  runApp(const ProviderScope(child: AdminApp()));
}
