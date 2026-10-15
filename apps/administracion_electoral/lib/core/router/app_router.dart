import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/archivo/archivo_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/cursos/courses_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/dispositivos/dispositivos_screen.dart';
import '../../features/elecciones/elecciones_screen.dart';
import '../../features/institucion/institution_screen.dart';
import '../../features/listas/listas_screen.dart';
import '../../features/padron/padron_screen.dart';
import '../../features/resultados/resultados_screen.dart';
import '../../features/sincronizacion/sincronizacion_screen.dart';
import '../../features/system/module_placeholder_screen.dart';
import '../../features/tutor/tutor_screen.dart';
import '../../shared/layout/admin_shell.dart';
import '../auth/auth_providers.dart';
import 'nav_items.dart';

/// Rutas de la aplicación de administración.
///
/// Navegación principal por barra superior (sin barra lateral permanente). Los
/// módulos aún no implementados renderizan una pantalla explícita de "en
/// construcción" en lugar de una ruta muerta.
///
/// La guarda de sesión redirige a `/login` mientras no haya un perfil de
/// personal resuelto, y devuelve al panel cuando la sesión se abre.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final profile = ref.read(authControllerProvider).value;
      final isAuthed = profile != null;
      final atLogin = state.matchedLocation == '/login';
      if (!isAuthed) return atLogin ? null : '/login';
      // Un tutor sin rol de gestión entra directo a su área y se mantiene ahí.
      final tutorOnly =
          profile.isTutor && !profile.isAdmin && !profile.isOperator;
      if (atLogin) return tutorOnly ? '/tutor' : '/';
      if (tutorOnly && !state.matchedLocation.startsWith('/tutor')) {
        return '/tutor';
      }
      if (!tutorOnly && state.matchedLocation.startsWith('/tutor')) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/tutor', builder: (_, _) => const TutorScreen()),
      ShellRoute(
        builder: (context, state, child) => AdminShell(
          location: state.matchedLocation,
          child: child,
        ),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
          for (final item in kAdminNav)
            if (item.path != '/')
              GoRoute(
                path: item.path,
                builder: (_, _) => switch (item.path) {
                  '/institucion' => const InstitutionScreen(),
                  '/cursos' => const CoursesScreen(),
                  '/padron' => const PadronScreen(),
                  '/listas' => const ListasScreen(),
                  '/elecciones' => const EleccionesScreen(),
                  '/dispositivos' => const DispositivosScreen(),
                  '/sincronizacion' => const SincronizacionScreen(),
                  '/resultados' => const ResultadosScreen(),
                  '/archivo' => const ArchivoScreen(),
                  _ => ModulePlaceholderScreen(title: item.label),
                },
              ),
        ],
      ),
    ],
  );
});
