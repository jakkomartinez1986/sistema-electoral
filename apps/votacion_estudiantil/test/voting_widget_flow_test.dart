import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:electoral_core/electoral_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kite_ui/shadcn.dart';
import 'package:votacion_estudiantil/core/offline/app_database.dart';
import 'package:votacion_estudiantil/core/providers.dart';
import 'package:votacion_estudiantil/core/theme/electoral_theme.dart';
import 'package:votacion_estudiantil/core/voting/ballot_gateway.dart';
import 'package:votacion_estudiantil/core/voting/outbox_sender.dart';
import 'package:votacion_estudiantil/features/voting/identification_screen.dart';
import 'package:votacion_estudiantil/features/voting/voting_providers.dart';

const String _salt = 'inst-demo';

Future<void> _seed(AppDatabase db) async {
  final now = DateTime.now().toUtc();
  await db.into(db.localConfig).insert(
        LocalConfigCompanion.insert(
          electionId: 'e1',
          electionName: 'Elección 2026',
          electionStatus: 'open',
          institutionId: _salt,
          institutionName: 'DEMO',
          deviceId: 'd1',
          deviceUid: 'DEV-1',
          deviceLabel: 'Mesa 1',
          verifierSalt: _salt,
          configVersion: 1,
          configHash: 'hash',
          downloadedAt: now,
          serverTime: now,
        ),
      );
  await db.into(db.localLists).insert(
        LocalListsCompanion.insert(id: 'l1', number: 1, name: 'Lista 1'),
      );
  await db.into(db.localCandidates).insert(
        LocalCandidatesCompanion.insert(
          id: 'c1',
          listId: 'l1',
          fullName: 'Ana Pérez',
          position: 'Presidente',
        ),
      );
  await db.into(db.localVoters).insert(
        LocalVotersCompanion.insert(
          voterRef: 'v1',
          code: 'DEMO-001',
          cedulaVerifier: Value(
            PadronVerifier.cedula(salt: _salt, cedula: '1710034065'),
          ),
          pinVerifier: Value(PadronVerifier.pin(salt: _salt, pin: '1234')),
        ),
      );
}

class _FakeGateway implements BallotCastApi {
  @override
  Future<CastBallotResult> castBallot({
    required String operationId,
    required String voterRef,
    required BallotOption option,
    required String ballotId,
  }) async =>
      const CastBallotResult(
        operationId: 'op',
        status: SyncOperationStatus.accepted,
      );

  @override
  Future<OperationStatus> getOperationStatus(String operationId) async =>
      const OperationStatus('op', SyncOperationStatus.accepted);
}

/// Botón cuyo texto es exactamente [label] (evita confundir el título del
/// AppBar con el botón cuando comparten texto).
Finder _button(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(ShadButton));

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('flujo completo: identificación → papeleta → confirmación → recibo',
      (tester) async {
    await _seed(db);

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        outboxSenderProvider.overrideWithValue(OutboxSender(db, _FakeGateway())),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ShadApp(
          theme: buildElectoralTheme(Brightness.light),
          initialRoute: IdentificationScreen.routeName,
          routes: {
            IdentificationScreen.routeName: (_) => const IdentificationScreen(),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Identificar votante'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), '1710034065');
    await tester.tap(_button('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Papeleta'), findsOneWidget,
        reason: 'tras identificar debe avanzar a la papeleta');

    // El botón de la papeleta debe estar en la barra inferior, no flotando en
    // el centro de la pantalla (regresión: `Center` expandía la barra).
    final continuar = tester.getCenter(find.text('Continuar'));
    expect(continuar.dy, greaterThan(400),
        reason: 'el botón Continuar debe estar en la barra inferior');

    await tester.tap(find.text('Lista 1'));
    await tester.pumpAndSettle();
    await tester.tap(_button('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Confirmar voto'), findsWidgets);

    await tester.tap(_button('Confirmar voto'));
    await tester.pumpAndSettle();

    expect(find.text('Voto recibido'), findsOneWidget);

    await tester.tap(_button('Listo'));
    await tester.pumpAndSettle();

    expect(find.text('Identificar votante'), findsOneWidget);
  });
}
