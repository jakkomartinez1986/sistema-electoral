import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:electoral_core/electoral_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:votacion_estudiantil/core/bundle/provisioning_repository.dart';
import 'package:votacion_estudiantil/core/offline/app_database.dart';
import 'package:votacion_estudiantil/core/voting/ballot_gateway.dart';
import 'package:votacion_estudiantil/core/voting/outbox_sender.dart';
import 'package:votacion_estudiantil/core/voting/padron_repository.dart';
import 'package:votacion_estudiantil/core/voting/voting_repository.dart';
import 'package:votacion_estudiantil/features/voting/voting_providers.dart';

const String _salt = 'inst-demo';

/// Bundle mínimo para probar `applyBundle` sin red.
DeviceBundle _deviceBundle({int version = 2, List<Object?>? voters}) =>
    DeviceBundle.fromJson({
      'device': {'device_id': 'd1', 'device_uid': 'DEV-1', 'label': 'Mesa 1'},
      'institution': {
        'id': _salt,
        'name': 'DEMO',
        'time_zone': 'America/Guayaquil',
      },
      'assignment': {
        'election_id': 'e1',
        'voting_table_id': 't1',
        'config_version': version,
      },
      'voting_table': {'id': 't1', 'code': 'T1', 'name': 'Mesa 1'},
      'verifier_salt': _salt,
      'config': {
        'election': {'id': 'e1', 'name': 'Elección 2026', 'status': 'open'},
        'lists': [
          {'id': 'l1', 'number': 1, 'name': 'Lista 1'},
        ],
        'candidates': [
          {
            'id': 'c1',
            'list_id': 'l1',
            'full_name': 'Ana Pérez',
            'position': 'Presidente',
            'order_index': 0,
          },
        ],
      },
      'config_version': version,
      'config_hash': 'hash-v$version',
      'voters': voters ??
          [
            {
              'voter_ref': 'v1',
              'code': 'DEMO-001',
              'voting_table_id': 't1',
              'cedula_verifier': PadronVerifier.cedula(
                salt: _salt,
                cedula: '1710034065',
              ),
              'pin_verifier': PadronVerifier.pin(salt: _salt, pin: '1234'),
            },
          ],
      'server_time': '2026-10-13T16:18:28.846239+00:00',
    });

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

/// Gateway falso para probar la cola sin red.
class _FakeGateway implements BallotCastApi {
  _FakeGateway({this.onCast, this.status});

  CastBallotResult Function()? onCast;
  OperationStatus Function()? status;
  int castCalls = 0;
  int statusCalls = 0;

  @override
  Future<CastBallotResult> castBallot({
    required String operationId,
    required String voterRef,
    required BallotOption option,
    required String ballotId,
  }) async {
    castCalls++;
    return onCast!();
  }

  @override
  Future<OperationStatus> getOperationStatus(String operationId) async {
    statusCalls++;
    return status?.call() ?? OperationStatus(operationId, null);
  }
}

void main() {
  late AppDatabase db;
  late ProvisioningRepository provisioning;
  late PadronRepository padron;
  late VotingRepository voting;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    provisioning = ProvisioningRepository(db);
    padron = PadronRepository(db, provisioning);
    voting = VotingRepository(db, provisioning);
    await _seed(db);
  });

  tearDown(() => db.close());

  test('identifica por cédula y por código+PIN contra el padrón local', () async {
    final byCedula = await padron.identifyByCedula('1710034065');
    expect(byCedula.canVote, isTrue);
    expect(byCedula.voterRef, 'v1');

    final byCode = await padron.identifyByCode(code: 'demo-001', pin: '1234');
    expect(byCode.canVote, isTrue);

    final badPin = await padron.identifyByCode(code: 'DEMO-001', pin: '0000');
    expect(badPin.result.status, VoterMatchStatus.badPin);
  });

  test('registra el voto localmente de forma atómica', () async {
    final receipt = await voting.recordVote(
      voterRef: 'v1',
      option: const BallotOption.list('l1'),
    );

    final outbox = await db.select(db.outbox).get();
    expect(outbox, hasLength(1));
    expect(outbox.single.status, 'pending');
    expect(outbox.single.optionType, 'list');
    expect(outbox.single.candidateListId, 'l1');
    expect(outbox.single.operationId, receipt.operationId);

    final participation = await db.select(db.participationLocal).get();
    expect(participation.single.voterRef, 'v1');
    expect(participation.single.synced, isFalse);

    final voter = await (db.select(db.localVoters)
          ..where((t) => t.voterRef.equals('v1')))
        .getSingle();
    expect(voter.hasVoted, isTrue);
  });

  test('un segundo voto del mismo votante se rechaza localmente', () async {
    await voting.recordVote(voterRef: 'v1', option: const BallotOption.blank());
    expect(
      () => voting.recordVote(voterRef: 'v1', option: const BallotOption.blank()),
      throwsA(isA<VotingException>()),
    );
  });

  test('el outbox confirma un voto aceptado y marca la participación', () async {
    await voting.recordVote(voterRef: 'v1', option: const BallotOption.list('l1'));

    final gateway = _FakeGateway(
      onCast: () => const CastBallotResult(
        operationId: 'op',
        status: SyncOperationStatus.accepted,
      ),
    );
    final summary = await OutboxSender(db, gateway).sendPending(force: true);

    expect(summary.accepted, 1);
    expect(gateway.castCalls, 1);

    final outbox = await db.select(db.outbox).get();
    expect(outbox.single.status, 'accepted');
    final participation = await db.select(db.participationLocal).get();
    expect(participation.single.synced, isTrue);
  });

  test('ante un fallo de red consulta el estado antes de reintentar', () async {
    await voting.recordVote(voterRef: 'v1', option: const BallotOption.blank());

    final gateway = _FakeGateway(
      onCast: () => throw const BallotNetworkException(),
      status: () => const OperationStatus(
        'op',
        SyncOperationStatus.accepted,
      ),
    );
    final summary = await OutboxSender(db, gateway).sendPending(force: true);

    expect(gateway.statusCalls, 1);
    expect(summary.accepted, 1);
    final outbox = await db.select(db.outbox).get();
    expect(outbox.single.status, 'accepted');
  });

  test('un conflicto del servidor se conserva como conflicto', () async {
    await voting.recordVote(voterRef: 'v1', option: const BallotOption.list('l1'));

    final gateway = _FakeGateway(
      onCast: () => const CastBallotResult(
        operationId: 'op',
        status: SyncOperationStatus.conflict,
        errorCode: 'duplicate_participation',
      ),
    );
    final summary = await OutboxSender(db, gateway).sendPending(force: true);

    expect(summary.conflict, 1);
    final outbox = await db.select(db.outbox).get();
    expect(outbox.single.status, 'conflict');
    expect(outbox.single.lastError, 'duplicate_participation');
  });

  test('dos sincronizaciones simultáneas no duplican el envío', () async {
    await voting.recordVote(voterRef: 'v1', option: const BallotOption.blank());

    final gateway = _FakeGateway(
      onCast: () => const CastBallotResult(
        operationId: 'op',
        status: SyncOperationStatus.accepted,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        outboxSenderProvider.overrideWithValue(OutboxSender(db, gateway)),
      ],
    );
    addTearDown(container.dispose);

    // Espera a que el controlador inicialice su estado (AsyncData(null)).
    await container.read(syncControllerProvider.future);
    final controller = container.read(syncControllerProvider.notifier);

    await Future.wait([
      controller.syncNow(force: true),
      controller.syncNow(force: true),
    ]);

    expect(gateway.castCalls, 1);
  });

  test('los votos pendientes sobreviven a reiniciar la aplicación', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final dir = Directory.systemTemp.createTempSync('votacion_restart');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File(p.join(dir.path, 'votacion_local.sqlite'));

    final first = AppDatabase(NativeDatabase(file));
    final firstProvisioning = ProvisioningRepository(first);
    await _seed(first);
    final receipt = await VotingRepository(first, firstProvisioning).recordVote(
      voterRef: 'v1',
      option: const BallotOption.list('l1'),
    );
    await first.close();

    // "Reinicio": se abre una nueva conexión sobre el mismo archivo.
    final restarted = AppDatabase(NativeDatabase(file));
    addTearDown(restarted.close);

    final outbox = await restarted.select(restarted.outbox).get();
    expect(outbox, hasLength(1));
    expect(outbox.single.status, 'pending');
    expect(outbox.single.operationId, receipt.operationId);

    final participation = await restarted.select(restarted.participationLocal).get();
    expect(participation.single.synced, isFalse);

    final gateway = _FakeGateway(
      onCast: () => const CastBallotResult(
        operationId: 'op',
        status: SyncOperationStatus.accepted,
      ),
    );
    final summary = await OutboxSender(restarted, gateway).sendPending(force: true);

    expect(summary.accepted, 1);
    final after = await restarted.select(restarted.outbox).get();
    expect(after.single.status, 'accepted');
  });

  test('re-descargar la configuración conserva el outbox y la participación', () async {
    await voting.recordVote(voterRef: 'v1', option: const BallotOption.list('l1'));

    await provisioning.applyBundle(_deviceBundle(version: 2));

    // El outbox pendiente y la participación sin sincronizar no se borran.
    final outbox = await db.select(db.outbox).get();
    expect(outbox, hasLength(1));
    expect(outbox.single.status, 'pending');

    final participation = await db.select(db.participationLocal).get();
    expect(participation, hasLength(1));
    expect(participation.single.synced, isFalse);

    // La configuración se actualizó de versión.
    final config = await provisioning.currentConfig();
    expect(config!.configVersion, 2);

    // Y re-descargar no rehabilita el voto: el votante sigue marcado.
    final byCedula = await padron.identifyByCedula('1710034065');
    expect(byCedula.found, isTrue);
    expect(byCedula.hasVoted, isTrue);
    expect(byCedula.canVote, isFalse);
    expect(
      () => voting.recordVote(voterRef: 'v1', option: const BallotOption.blank()),
      throwsA(isA<VotingException>()),
    );
  });
}
