import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kite_ui/kite_ui.dart';
import 'package:kite_ui/shadcn.dart';

import '../../core/auth/auth_providers.dart';
import '../../shared/widgets/module_page.dart';
import '../../shared/widgets/table_helpers.dart';
import '../elecciones/data/elections_repository.dart';
import '../elecciones/elections_providers.dart';
import 'data/devices_repository.dart';
import 'devices_providers.dart';

/// Módulo G — Dispositivos.
///
/// Registro, autorización y asignación de dispositivos. Un dispositivo revocado
/// no acepta nuevas operaciones (lo valida el backend en `cast_ballot`).
class DispositivosScreen extends ConsumerWidget {
  const DispositivosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = KiteText.of(context);
    final institutionId = ref.watch(currentInstitutionIdProvider);
    final devicesAsync = ref.watch(devicesProvider);
    return ModulePage(
      title: 'Dispositivos',
      description:
          'Dispositivos de votación autorizados. El emparejamiento final se '
          'realiza con la app de votación mediante un código de un solo uso.',
      actions: [
        KiteButton(
          enabled: institutionId != null,
          onPressed: institutionId == null
              ? null
              : () => _openDeviceForm(context, ref, institutionId, null),
          leading: const Icon(Icons.add, size: 16),
          child: const Text('Nuevo dispositivo'),
        ),
        KiteButton.outline(
          onPressed: () => ref.invalidate(devicesProvider),
          leading: const Icon(Icons.refresh, size: 16),
          child: const Text('Actualizar'),
        ),
      ],
      child: devicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => KiteAlert(
          title: 'No se pudieron cargar los dispositivos',
          description: '$error',
          tone: KiteTone.danger,
        ),
        data: (list) {
          if (list.isEmpty) {
            return const KiteAlert(
              title: 'Sin dispositivos registrados',
              description:
                  'Registra un dispositivo para poder asociarlo a una elección '
                  'y generar su código de emparejamiento.',
              tone: KiteTone.warning,
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${list.length} dispositivos', style: t.muted),
              const SizedBox(height: KiteSpace.sm),
              Expanded(
                child: KiteDataTable(
                  columns: [
                    trinaTextColumn('Etiqueta', 'label', width: 200),
                    trinaTextColumn('UID de hardware', 'uid', width: 200),
                    trinaTextColumn('Estado', 'status', width: 110),
                    trinaTextColumn('Versión', 'version', width: 110),
                    trinaTextColumn('Última vez', 'last', width: 170),
                  ],
                  rows: [
                    for (final d in list)
                      trinaRow({
                        'label': d.label,
                        'uid': d.deviceUid,
                        'status': deviceStatusLabel(d.status),
                        'version': d.appVersion ?? '—',
                        'last': _shortTs(d.lastSeenAt),
                      }),
                  ],
                  onRowTap: (index) => _openDeviceDetail(context, ref, list[index]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _shortTs(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

Future<void> _openDeviceForm(
  BuildContext context,
  WidgetRef ref,
  String institutionId,
  VotingDevice? device,
) async {
  final saved = await kiteSheet<bool>(
    context,
    title: device == null ? 'Nuevo dispositivo' : 'Editar dispositivo',
    description: 'Etiqueta visible y UID de hardware.',
    body: _DeviceForm(institutionId: institutionId, device: device),
  );
  if (saved != true) return;
  ref.invalidate(devicesProvider);
  if (context.mounted) {
    KiteToast.show(
      context,
      title:
          device == null ? 'Dispositivo registrado' : 'Dispositivo actualizado',
      tone: KiteTone.success,
    );
  }
}

class _DeviceForm extends ConsumerStatefulWidget {
  const _DeviceForm({required this.institutionId, this.device});

  final String institutionId;
  final VotingDevice? device;

  @override
  ConsumerState<_DeviceForm> createState() => _DeviceFormState();
}

class _DeviceFormState extends ConsumerState<_DeviceForm> {
  late final TextEditingController _label;
  late final TextEditingController _uid;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: widget.device?.label ?? '');
    _uid = TextEditingController(text: widget.device?.deviceUid ?? '');
  }

  @override
  void dispose() {
    _label.dispose();
    _uid.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final label = _label.text.trim();
    final uid = _uid.text.trim();
    if (label.isEmpty || uid.isEmpty) {
      KiteToast.show(
        context,
        title: 'Etiqueta y UID son obligatorios',
        tone: KiteTone.danger,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(devicesRepositoryProvider);
      if (widget.device == null) {
        await repo.createDevice(
          institutionId: widget.institutionId,
          deviceUid: uid,
          label: label,
        );
      } else {
        await repo.updateDevice(
          widget.device!.id,
          deviceUid: uid,
          label: label,
          status: widget.device!.status,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      KiteToast.show(
        context,
        title: 'No se pudo guardar',
        description: '$error',
        tone: KiteTone.danger,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KiteField(
          label: 'Etiqueta',
          child: KiteInput(controller: _label, placeholder: 'Tablet mesa 1'),
        ),
        KiteField(
          label: 'UID de hardware',
          hint: 'Identificador único del dispositivo.',
          child: KiteInput(controller: _uid, placeholder: 'IMEI / serial'),
        ),
        const SizedBox(height: KiteSpace.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            KiteButton.outline(
              enabled: !_saving,
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            const SizedBox(width: KiteSpace.sm),
            KiteButton(
              enabled: !_saving,
              onPressed: _save,
              child: Text(_saving ? 'Guardando…' : 'Guardar'),
            ),
          ],
        ),
      ],
    );
  }
}

Future<void> _openDeviceDetail(
  BuildContext context,
  WidgetRef ref,
  VotingDevice device,
) async {
  await kiteSheet<void>(
    context,
    title: device.label,
    description: 'UID: ${device.deviceUid} · '
        '${deviceStatusLabel(device.status)}',
    width: 560,
    body: _DeviceDetail(device: device),
  );
  ref.invalidate(devicesProvider);
  ref.invalidate(deviceAssignmentsProvider(device.id));
}

class _DeviceDetail extends ConsumerStatefulWidget {
  const _DeviceDetail({required this.device});

  final VotingDevice device;

  @override
  ConsumerState<_DeviceDetail> createState() => _DeviceDetailState();
}

class _DeviceDetailState extends ConsumerState<_DeviceDetail> {
  final _ttl = TextEditingController(text: '30');
  String? _assignElectionId;
  String? _assignTableId;
  bool _busy = false;

  @override
  void dispose() {
    _ttl.dispose();
    super.dispose();
  }

  Future<void> _setStatus(String status) async {
    if (status == 'revoked') {
      final confirmed = await kiteConfirm(
        context,
        title: 'Revocar dispositivo',
        message: 'Un dispositivo revocado no acepta nuevas operaciones. '
            '¿Confirmas?',
        confirmLabel: 'Revocar',
      );
      if (!confirmed) return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(devicesRepositoryProvider).updateDevice(
            widget.device.id,
            deviceUid: widget.device.deviceUid,
            label: widget.device.label,
            status: status,
          );
      if (!mounted) return;
      setState(() => _busy = false);
      ref.invalidate(devicesProvider);
      KiteToast.show(
        context,
        title: 'Estado: ${deviceStatusLabel(status)}',
        tone: KiteTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      KiteToast.show(
        context,
        title: 'No se pudo cambiar el estado',
        description: '$error',
        tone: KiteTone.danger,
      );
    }
  }

  Future<void> _generateCode() async {
    final ttl = int.tryParse(_ttl.text.trim());
    if (ttl == null || ttl < 1) {
      KiteToast.show(
        context,
        title: 'Validez en minutos debe ser un número positivo',
        tone: KiteTone.danger,
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final code = await ref
          .read(devicesRepositoryProvider)
          .createEnrollmentCode(widget.device.id, ttl);
      if (!mounted) return;
      setState(() => _busy = false);
      _showEnrollmentCode(context, code, ttl);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      KiteToast.show(
        context,
        title: 'No se pudo generar el código',
        description: '$error',
        tone: KiteTone.danger,
      );
    }
  }

  Future<void> _assign() async {
    if (_assignElectionId == null) {
      KiteToast.show(
        context,
        title: 'Selecciona una elección',
        tone: KiteTone.danger,
      );
      return;
    }
    try {
      await ref.read(devicesRepositoryProvider).assignDevice(
        deviceId: widget.device.id,
        electionId: _assignElectionId!,
        votingTableId: _assignTableId,
      );
      if (!mounted) return;
      setState(() {});
      ref.invalidate(deviceAssignmentsProvider(widget.device.id));
      KiteToast.show(
        context,
        title: 'Dispositivo asignado',
        tone: KiteTone.success,
      );
    } catch (error) {
      if (mounted) {
        KiteToast.show(
          context,
          title: 'No se pudo asignar',
          description: '$error',
          tone: KiteTone.danger,
        );
      }
    }
  }

  Future<void> _revokeAssignment(DeviceAssignment assignment) async {
    final confirmed = await kiteConfirm(
      context,
      title: 'Revocar asignación',
      message:
          'Se revocará la asignación de este dispositivo a la elección '
          'seleccionada.',
      confirmLabel: 'Revocar',
    );
    if (!confirmed) return;
    try {
      await ref
          .read(devicesRepositoryProvider)
          .revokeAssignment(assignment.id);
      ref.invalidate(deviceAssignmentsProvider(widget.device.id));
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        KiteToast.show(
          context,
          title: 'No se pudo revocar',
          description: '$error',
          tone: KiteTone.danger,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = KiteText.of(context);
    final device = widget.device;
    final assignmentsAsync = ref.watch(deviceAssignmentsProvider(device.id));
    final elections =
        ref.watch(electionsProvider).value ?? const <Election>[];
    final tables =
        _assignElectionId == null
        ? const <VotingTable>[]
        : ref.watch(electionTablesProvider(_assignElectionId!)).value ??
              const <VotingTable>[];
    final electionName = {for (final e in elections) e.id: e.name};
    final tableName = {for (final v in tables) v.id: v.code};

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DetailRow(label: 'Etiqueta', value: device.label),
          DetailRow(label: 'UID', value: device.deviceUid),
          DetailRow(
            label: 'Versión de app',
            value: device.appVersion ?? '—',
          ),
          DetailRow(label: 'Última sincronización', value: _shortTs(device.lastSeenAt)),
          const SizedBox(height: KiteSpace.lg),
          Text('Estado', style: t.small.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: KiteSpace.sm),
          Wrap(
            spacing: KiteSpace.sm,
            runSpacing: KiteSpace.sm,
            children: [
              for (final status in kDeviceStatuses)
                status == 'revoked'
                    ? KiteButton.destructive(
                        enabled: !_busy && device.status != status,
                        onPressed: () => _setStatus(status),
                        child: Text(deviceStatusLabel(status)),
                      )
                    : KiteButton.outline(
                        enabled: !_busy && device.status != status,
                        onPressed: () => _setStatus(status),
                        child: Text(deviceStatusLabel(status)),
                      ),
            ],
          ),
          const SizedBox(height: KiteSpace.xl),
          Text(
            'Código de emparejamiento',
            style: t.small.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: KiteSpace.sm),
          Row(
            children: [
              SizedBox(
                width: 140,
                child: KiteInput(
                  controller: _ttl,
                  placeholder: 'Validez (min)',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: KiteSpace.sm),
              KiteButton(
                enabled: !_busy,
                onPressed: _generateCode,
                leading: const Icon(Icons.key_outlined, size: 16),
                child: const Text('Generar código'),
              ),
            ],
          ),
          const SizedBox(height: KiteSpace.xl),
          Text(
            'Asignaciones',
            style: t.small.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: KiteSpace.sm),
          assignmentsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: KiteSpace.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => KiteAlert(
              title: 'No se pudieron cargar las asignaciones',
              description: '$error',
              tone: KiteTone.danger,
            ),
            data: (assignments) {
              if (assignments.isEmpty) {
                return Text('Sin asignaciones.', style: t.muted);
              }
              return Column(
                children: [
                  for (final a in assignments)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${electionName[a.electionId] ?? 'Elección'}'
                              '${a.votingTableId == null ? '' : ' · Mesa ${tableName[a.votingTableId] ?? '—'}'}'
                              '${a.revokedAt == null ? '' : ' (revocada)'}',
                              style: t.small,
                            ),
                          ),
                          if (a.revokedAt == null)
                            IconButton(
                              onPressed: () => _revokeAssignment(a),
                              icon: const Icon(Icons.link_off, size: 16),
                              tooltip: 'Revocar asignación',
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: KiteSpace.md),
          Text('Asignar a elección', style: t.muted),
          const SizedBox(height: KiteSpace.sm),
          KiteSelect<String>(
            options: [for (final e in elections) e.id],
            labelOf: (id) => electionName[id] ?? '—',
            placeholder: 'Elección',
            onChanged: (value) => setState(() {
              _assignElectionId = value;
              _assignTableId = null;
            }),
          ),
          const SizedBox(height: KiteSpace.sm),
          KiteSelect<String>(
            options: [for (final v in tables) v.id],
            labelOf: (id) => tableName[id] ?? '—',
            placeholder: _assignElectionId == null
                ? 'Primero selecciona una elección'
                : 'Mesa (opcional)',
            onChanged: (value) =>
                setState(() => _assignTableId = value),
          ),
          const SizedBox(height: KiteSpace.sm),
          Align(
            alignment: Alignment.centerRight,
            child: KiteButton(
              onPressed: _assign,
              leading: const Icon(Icons.link, size: 16),
              child: const Text('Asignar'),
            ),
          ),
        ],
      ),
    );
  }
}

void _showEnrollmentCode(BuildContext context, String code, int ttlMinutes) {
  showShadDialog<void>(
    context: context,
    builder: (dialogContext) => ShadDialog.alert(
      title: const Text('Código de emparejamiento'),
      description: Padding(
        padding: const EdgeInsets.only(top: KiteSpace.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ingresa este código en la app de votación. Es de un solo uso y '
              'expira en $ttlMinutes minutos. Este es el único momento en que '
              'se muestra.',
            ),
            const SizedBox(height: KiteSpace.lg),
            SelectableText(
              code,
              style: KiteText.of(context).h4.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
      actions: [
        ShadButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );
}