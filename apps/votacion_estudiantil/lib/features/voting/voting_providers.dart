import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/voting/ballot_gateway.dart';
import '../../core/voting/outbox_sender.dart';
import '../../core/voting/padron_repository.dart';
import '../../core/voting/voting_repository.dart';
import 'ballot_catalog.dart';

final padronRepositoryProvider = Provider<PadronRepository>(
  (ref) => PadronRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(provisioningRepositoryProvider),
  ),
);

final votingRepositoryProvider = Provider<VotingRepository>(
  (ref) => VotingRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(provisioningRepositoryProvider),
  ),
);

final ballotGatewayProvider = Provider<BallotGateway>(
  (ref) => BallotGateway(ref.watch(supabaseClientProvider)),
);

final outboxSenderProvider = Provider<OutboxSender>(
  (ref) => OutboxSender(
    ref.watch(appDatabaseProvider),
    ref.watch(ballotGatewayProvider),
  ),
);

/// Operaciones todavía sin confirmar por el servidor (indicador en pantalla).
final outboxPendingProvider = StreamProvider<int>(
  (ref) => ref.watch(outboxSenderProvider).watchPendingCount(),
);

/// Oferta electoral local para armar la papeleta.
final ballotCatalogProvider = FutureProvider<BallotCatalog>((ref) async {
  final provisioning = ref.watch(provisioningRepositoryProvider);
  return BallotCatalog(
    lists: await provisioning.loadLists(),
    candidates: await provisioning.loadCandidates(),
  );
});

/// Votante identificado en memoria. Se limpia al terminar el flujo para no
/// arrastrar identidad entre papeletas.
class VotingSession {
  const VotingSession({required this.voterRef});

  final String voterRef;
}

class VotingSessionController extends Notifier<VotingSession?> {
  @override
  VotingSession? build() => null;

  void identify(String voterRef) => state = VotingSession(voterRef: voterRef);

  void clear() => state = null;
}

final votingSessionProvider =
    NotifierProvider<VotingSessionController, VotingSession?>(
      VotingSessionController.new,
    );

/// Sincronización manual de la cola de salida.
class SyncController extends AsyncNotifier<SyncSummary?> {
  @override
  Future<SyncSummary?> build() async => null;

  Future<void> syncNow({bool force = true}) async {
    // Evita dos pasadas simultáneas (p. ej. la automática tras cada voto y la
    // manual del operador). La cola solo selecciona filas `pending`/`error`, así
    // que una pasada en curso no se duplica.
    if (state.isLoading) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(outboxSenderProvider).sendPending(force: force),
    );
  }
}

final syncControllerProvider =
    AsyncNotifierProvider<SyncController, SyncSummary?>(SyncController.new);
