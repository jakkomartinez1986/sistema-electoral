import 'package:administracion_electoral/app.dart';
import 'package:administracion_electoral/core/auth/auth_providers.dart';
import 'package:administracion_electoral/features/system/not_configured_app.dart';
import 'package:electoral_core/electoral_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sesión simulada sin perfil: la guarda debe enviar a la pantalla de acceso.
class _SignedOutAuth extends AuthController {
  @override
  Future<StaffProfile?> build() async => null;
}

void main() {
  testWidgets('sin sesión, la administración muestra el acceso', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authControllerProvider.overrideWith(_SignedOutAuth.new)],
        child: const AdminApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Administración Electoral'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
  });

  testWidgets('sin configuración, explica cómo inyectar las variables',
      (tester) async {
    await tester.pumpWidget(const NotConfiguredApp());
    await tester.pumpAndSettle();

    expect(find.text('Falta configurar el backend'), findsOneWidget);
  });
}
