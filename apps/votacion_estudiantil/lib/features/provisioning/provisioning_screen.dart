import 'package:electoral_core/electoral_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../core/bundle/bundle_repository.dart';
import '../../core/offline/app_database.dart';
import '../../core/providers.dart';
import '../kiosk/kiosk.dart';
import '../voting/identification_screen.dart';
import '../voting/voting_providers.dart';

/// Pantalla del dispositivo ya vinculado: descarga y verifica la configuración
/// electoral y el padrón de su mesa, los guarda para votar sin conexión y, una
/// vez configurado, habilita el flujo de votación.
class ProvisioningScreen extends ConsumerStatefulWidget {
  const ProvisioningScreen({super.key, this.email});

  final String? email;

  @override
  ConsumerState<ProvisioningScreen> createState() => _ProvisioningScreenState();
}

class _ProvisioningScreenState extends ConsumerState<ProvisioningScreen> {
  @override
  void initState() {
    super.initState();
    // Al abrir con conexión, se intenta sincronizar lo pendiente sin forzar el
    // backoff. Si no hay red, queda para el siguiente intento.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncControllerProvider.notifier).syncNow(force: false);
    });
  }

  Future<void> _startVoting(LocalConfigData config) async {
    final status = ElectionStatus.fromDb(config.electionStatus);
    if (!status.acceptsBallots) {
      KiteToast.show(
        context,
        title: 'La votación no está abierta',
        description: 'Consulta con el personal electoral.',
        tone: KiteTone.warning,
      );
      return;
    }
    // Bloquea el equipo en el flujo de votación hasta que el personal salga.
    await ref.read(kioskModeProvider.notifier).enable();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const IdentificationScreen(),
        settings: const RouteSettings(name: IdentificationScreen.routeName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = KiteColors.of(context);
    final config = ref.watch(localConfigProvider).value;
    final provisioning = ref.watch(provisioningControllerProvider);
    final downloading = provisioning.isLoading;

    void download() =>
        ref.read(provisioningControllerProvider.notifier).download();

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(KiteSpace.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(email: widget.email),
                  const SizedBox(height: KiteSpace.lg),
                  if (provisioning.hasError) ...[
                    KiteAlert(
                      title: 'No se pudo descargar',
                      description: _messageOf(provisioning.error!),
                      tone: KiteTone.danger,
                    ),
                    const SizedBox(height: KiteSpace.lg),
                  ],
                  if (provisioning.value case final report?
                      when report.warnings.isNotEmpty) ...[
                    KiteAlert(
                      title: 'Revisa antes de votar',
                      description: report.warnings.join('\n'),
                      tone: KiteTone.warning,
                    ),
                    const SizedBox(height: KiteSpace.lg),
                  ],
                  if (config == null)
                    _DownloadCard(
                      downloading: downloading,
                      onDownload: download,
                    )
                  else
                    _ConfigCard(
                      config: config,
                      downloading: downloading,
                      onDownload: download,
                      onStartVoting: () => _startVoting(config),
                    ),
                  if (config != null) ...[
                    const SizedBox(height: KiteSpace.lg),
                    const _SyncCard(),
                  ],
                  const SizedBox(height: KiteSpace.lg),
                  const _SignOutButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _messageOf(Object error) =>
      error is BundleException ? error.message : 'Error inesperado: $error';
}

class _Header extends StatelessWidget {
  const _Header({this.email});

  final String? email;

  @override
  Widget build(BuildContext context) {
    final t = KiteText.of(context);
    final c = KiteColors.of(context);
    return KiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_outlined, size: 28, color: c.primary),
              const SizedBox(width: KiteSpace.sm),
              Expanded(child: Text('Dispositivo vinculado', style: t.h3)),
              const KiteBadge('Autorizado', tone: KiteTone.success),
            ],
          ),
          if (email != null) ...[
            const SizedBox(height: KiteSpace.sm),
            Text(
              'Credencial: $email',
              style: t.muted.copyWith(fontFamily: 'monospace'),
            ),
          ],
        ],
      ),
    );
  }
}

class _DownloadCard extends StatelessWidget {
  const _DownloadCard({required this.downloading, required this.onDownload});

  final bool downloading;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final t = KiteText.of(context);
    return KiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Preparar este equipo', style: t.h3),
          const SizedBox(height: KiteSpace.sm),
          Text(
            'Descarga la configuración de la elección y el padrón de la mesa '
            'asignada. Después podrás votar aunque se pierda la conexión.',
            style: t.muted,
          ),
          const SizedBox(height: KiteSpace.lg),
          KiteButton(
            expands: true,
            enabled: !downloading,
            onPressed: onDownload,
            leading: const Icon(Icons.cloud_download_outlined),
            child: Text(
              downloading ? 'Descargando…' : 'Descargar configuración y padrón',
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigCard extends StatelessWidget {
  const _ConfigCard({
    required this.config,
    required this.downloading,
    required this.onDownload,
    required this.onStartVoting,
  });

  final LocalConfigData config;
  final bool downloading;
  final VoidCallback onDownload;
  final VoidCallback onStartVoting;

  @override
  Widget build(BuildContext context) {
    final t = KiteText.of(context);
    final status = ElectionStatus.fromDb(config.electionStatus);
    return KiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(config.electionName, style: t.h3)),
              KiteBadge(electionStatusLabel(status), tone: _statusTone(status)),
            ],
          ),
          const SizedBox(height: KiteSpace.sm),
          Text(config.institutionName, style: t.muted),
          const SizedBox(height: KiteSpace.lg),
          _Detail(
            label: 'Mesa',
            value: config.votingTableName ?? config.votingTableCode ?? 'Todas',
          ),
          _Detail(
            label: 'Versión de configuración',
            value: 'v${config.configVersion}',
          ),
          _Detail(
            label: 'Integridad',
            value: config.configHash.length <= 12
                ? config.configHash
                : config.configHash.substring(0, 12),
            monospace: true,
          ),
          _Detail(
            label: 'Descargado',
            value: DateFormat('yyyy-MM-dd HH:mm')
                .format(config.downloadedAt.toLocal()),
          ),
          const SizedBox(height: KiteSpace.lg),
          Row(
            children: [
              Expanded(
                child: _Stat(label: 'Listas', value: '${config.listCount}'),
              ),
              Expanded(
                child: _Stat(
                  label: 'Candidatos',
                  value: '${config.candidateCount}',
                ),
              ),
              Expanded(
                child: _Stat(label: 'Padrón', value: '${config.voterCount}'),
              ),
            ],
          ),
          const SizedBox(height: KiteSpace.lg),
          KiteButton(
            expands: true,
            enabled: status.acceptsBallots,
            onPressed: onStartVoting,
            leading: const Icon(Icons.how_to_vote_outlined),
            child: const Text('Comenzar a votar'),
          ),
          const SizedBox(height: KiteSpace.sm),
          KiteButton.outline(
            expands: true,
            enabled: !downloading,
            onPressed: onDownload,
            leading: const Icon(Icons.refresh),
            child: Text(downloading ? 'Descargando…' : 'Volver a descargar'),
          ),
        ],
      ),
    );
  }
}

class _SyncCard extends ConsumerWidget {
  const _SyncCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = KiteText.of(context);
    final c = KiteColors.of(context);
    final pending = ref.watch(outboxPendingProvider).value ?? 0;
    final sync = ref.watch(syncControllerProvider);
    final syncing = sync.isLoading;
    final summary = sync.value;

    return KiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.sync, size: 22, color: c.primary),
              const SizedBox(width: KiteSpace.sm),
              Expanded(child: Text('Sincronización', style: t.h4)),
              KiteBadge(
                pending == 0 ? 'Al día' : '$pending pendiente(s)',
                tone: pending == 0 ? KiteTone.success : KiteTone.warning,
              ),
            ],
          ),
          const SizedBox(height: KiteSpace.sm),
          Text(
            'Los votos se guardan localmente y se envían al servidor cuando hay '
            'conexión. Un error de red no pierde el voto: se reintenta por su '
            'identificador de operación.',
            style: t.muted,
          ),
          if (summary != null) ...[
            const SizedBox(height: KiteSpace.sm),
            Text(
              'Última pasada: ${summary.accepted} aceptado(s), '
              '${summary.rejected} rechazado(s), '
              '${summary.conflict} conflicto(s), '
              '${summary.errors} con error de red.',
              style: t.small,
            ),
          ],
          const SizedBox(height: KiteSpace.lg),
          KiteButton.outline(
            expands: true,
            enabled: !syncing,
            onPressed: () =>
                ref.read(syncControllerProvider.notifier).syncNow(),
            leading: const Icon(Icons.cloud_sync_outlined),
            child: Text(syncing ? 'Sincronizando…' : 'Sincronizar ahora'),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = KiteText.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.small),
        const SizedBox(height: 2),
        Text(value, style: t.h3),
      ],
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.label,
    required this.value,
    this.monospace = false,
  });

  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final t = KiteText.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: t.small.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: monospace
                  ? t.muted.copyWith(fontFamily: 'monospace')
                  : t.p,
            ),
          ),
        ],
      ),
    );
  }
}

class _SignOutButton extends ConsumerWidget {
  const _SignOutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return KiteButton.outline(
      expands: true,
      onPressed: () async {
        await ref.read(supabaseClientProvider).auth.signOut();
      },
      leading: const Icon(Icons.link_off),
      child: const Text('Desvincular este equipo'),
    );
  }
}

String electionStatusLabel(ElectionStatus status) => switch (status) {
  ElectionStatus.draft => 'Borrador',
  ElectionStatus.ready => 'Lista',
  ElectionStatus.open => 'Abierta',
  ElectionStatus.closing => 'En cierre',
  ElectionStatus.closed => 'Cerrada',
  ElectionStatus.archived => 'Archivada',
  ElectionStatus.cancelled => 'Cancelada',
};

KiteTone _statusTone(ElectionStatus status) => switch (status) {
  ElectionStatus.open => KiteTone.success,
  ElectionStatus.ready => KiteTone.info,
  ElectionStatus.closing => KiteTone.warning,
  ElectionStatus.cancelled => KiteTone.danger,
  _ => KiteTone.neutral,
};
