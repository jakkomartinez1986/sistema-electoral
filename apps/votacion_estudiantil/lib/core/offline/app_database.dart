import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// Configuración de la elección descargada (fila única, id = 'current').
///
/// Es un espejo local de lo que el servidor entregó al dispositivo, para que la
/// papeleta y el padrón funcionen sin conexión.
class LocalConfig extends Table {
  TextColumn get id => text().withDefault(const Constant('current'))();

  TextColumn get electionId => text()();
  TextColumn get electionName => text()();
  TextColumn get electionStatus => text()();
  TextColumn get timeZone =>
      text().withDefault(const Constant('America/Guayaquil'))();
  DateTimeColumn get opensAt => dateTime().nullable()();
  DateTimeColumn get closesAt => dateTime().nullable()();

  TextColumn get institutionId => text()();
  TextColumn get institutionName => text()();

  TextColumn get deviceId => text()();
  TextColumn get deviceUid => text()();
  TextColumn get deviceLabel => text()();

  TextColumn get votingTableId => text().nullable()();
  TextColumn get votingTableCode => text().nullable()();
  TextColumn get votingTableName => text().nullable()();

  /// Sal para recomputar verificadores (id de institución).
  TextColumn get verifierSalt => text()();

  IntColumn get configVersion => integer()();
  TextColumn get configHash => text()();

  /// Contadores del paquete para mostrar sin recontar en memoria.
  IntColumn get listCount => integer().withDefault(const Constant(0))();
  IntColumn get candidateCount => integer().withDefault(const Constant(0))();
  IntColumn get voterCount => integer().withDefault(const Constant(0))();

  DateTimeColumn get downloadedAt => dateTime()();
  DateTimeColumn get serverTime => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Listas de la elección.
class LocalLists extends Table {
  TextColumn get id => text()();
  IntColumn get number => integer()();
  TextColumn get name => text()();
  TextColumn get slogan => text().nullable()();
  TextColumn get emblemPath => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Candidatos de cada lista.
class LocalCandidates extends Table {
  TextColumn get id => text()();
  TextColumn get listId => text().references(LocalLists, #id)();
  TextColumn get fullName => text()();
  TextColumn get position => text()();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
  TextColumn get photoPath => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Padrón local: referencias opacas + verificadores (sin identidad en claro).
class LocalVoters extends Table {
  TextColumn get voterRef => text()();
  TextColumn get code => text()();
  TextColumn get votingTableId => text().nullable()();
  TextColumn get cedulaVerifier => text().nullable()();
  TextColumn get pinVerifier => text().nullable()();

  /// Participación registrada localmente (aún sin sincronizar o ya aceptada).
  BoolColumn get hasVoted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get votedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {voterRef};
}

/// Cola de salida de votos (outbox). Idempotencia por [operationId].
class Outbox extends Table {
  TextColumn get operationId => text()();
  TextColumn get voterRef => text()();
  TextColumn get optionType => text()();
  TextColumn get candidateListId => text().nullable()();
  TextColumn get ballotId => text()();

  /// pending | sending | accepted | rejected | conflict | error
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {operationId};
}

/// Registro local de participación (se conserva aunque el outbox se vacíe).
class ParticipationLocal extends Table {
  TextColumn get voterRef => text()();
  TextColumn get operationId => text()();
  DateTimeColumn get castAt => dateTime()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {voterRef};
}

/// Bitácora local de sincronización (diagnóstico).
class SyncLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get level => text()();
  TextColumn get message => text()();
  TextColumn get detail => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

@DriftDatabase(
  tables: [
    LocalConfig,
    LocalLists,
    LocalCandidates,
    LocalVoters,
    Outbox,
    ParticipationLocal,
    SyncLog,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, 'votacion_local.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
