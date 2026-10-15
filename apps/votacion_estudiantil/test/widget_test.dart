import 'package:flutter_test/flutter_test.dart';
import 'package:votacion_estudiantil/features/setup/not_configured_app.dart';

void main() {
  testWidgets('sin configuración, explica cómo inyectar las variables', (
    tester,
  ) async {
    await tester.pumpWidget(const NotConfiguredApp());
    await tester.pumpAndSettle();

    expect(find.text('Falta configurar el backend'), findsOneWidget);
  });
}
