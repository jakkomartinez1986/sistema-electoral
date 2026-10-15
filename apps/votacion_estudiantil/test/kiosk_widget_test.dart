import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kite_ui/shadcn.dart';
import 'package:votacion_estudiantil/core/offline/app_database.dart';
import 'package:votacion_estudiantil/core/providers.dart';
import 'package:votacion_estudiantil/core/theme/electoral_theme.dart';
import 'package:votacion_estudiantil/features/kiosk/kiosk.dart';
import 'package:votacion_estudiantil/features/voting/identification_screen.dart';

/// Raíz de prueba que simula el arranque desde el aprovisionamiento: activa el
/// modo kiosco y empuja la identificación con su nombre de ruta.
class _FakeProvisioning extends ConsumerWidget {
  const _FakeProvisioning();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: ShadButton(
          onPressed: () {
            ref.read(kioskModeProvider.notifier).enable();
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const IdentificationScreen(),
                settings: const RouteSettings(
                  name: IdentificationScreen.routeName,
                ),
              ),
            );
          },
          child: const Text('Comenzar'),
        ),
      ),
    );
  }
}

Future<void> _seed(AppDatabase db) async {
  final now = DateTime.now().toUtc();
  await db
      .into(db.localConfig)
      .insert(
        LocalConfigCompanion.insert(
          electionId: 'e1',
          electionName: 'Elección 2026',
          electionStatus: 'open',
          institutionId: 'inst-demo',
          institutionName: 'Escuela DEMO',
          deviceId: 'd1',
          deviceUid: 'DEV-1',
          deviceLabel: 'Mesa 1',
          verifierSalt: 'inst-demo',
          configVersion: 1,
          configHash: 'hash',
          downloadedAt: now,
          serverTime: now,
        ),
      );
}

/// Simula el botón físico de "atrás" del sistema operativo.
Future<void> _systemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.navigation.name,
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
  await tester.pumpAndSettle();
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    await _seed(db);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ShadApp(
          theme: buildElectoralTheme(Brightness.light),
          home: const _FakeProvisioning(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comenzar'));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('entrar a votar activa el modo kiosco y oculta el botón atrás', (
    tester,
  ) async {
    final container = await pumpApp(tester);

    expect(
      container.read(kioskModeProvider),
      isTrue,
      reason: 'el modo kiosco debe quedar activo durante la votación',
    );
    expect(find.text('Identificar votante'), findsOneWidget);
    expect(
      find.byType(BackButton),
      findsNothing,
      reason: 'no debe ofrecerse salida por la barra de la app',
    );

    await _systemBack(tester);
    expect(
      find.text('Identificar votante'),
      findsOneWidget,
      reason: 'el botón atrás del sistema no debe abandonar el flujo',
    );
  });

  testWidgets('mantener pulsado el encabezado pide confirmación para salir', (
    tester,
  ) async {
    final container = await pumpApp(tester);

    await tester.longPress(find.text('Escuela DEMO'));
    await tester.pumpAndSettle();

    expect(find.text('Salir del modo kiosco'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Identificar votante'), findsOneWidget);
    expect(
      container.read(kioskModeProvider),
      isTrue,
      reason: 'cancelar no debe desbloquear el equipo',
    );
  });

  testWidgets('confirmar la salida desbloquea el equipo y vuelve al inicio', (
    tester,
  ) async {
    final container = await pumpApp(tester);

    await tester.longPress(find.text('Escuela DEMO'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Salir'));
    await tester.pumpAndSettle();

    expect(
      container.read(kioskModeProvider),
      isFalse,
      reason: 'confirmar debe desactivar el modo kiosco',
    );
    expect(
      find.text('Comenzar'),
      findsOneWidget,
      reason: 'debe volver a la pantalla de configuración',
    );
    expect(find.text('Identificar votante'), findsNothing);
  });
}
