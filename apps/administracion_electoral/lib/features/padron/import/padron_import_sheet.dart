import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../../shared/widgets/table_helpers.dart';
import '../../elecciones/data/elections_repository.dart';
import '../../elecciones/elections_providers.dart';
import '../data/padron_import_repository.dart';
import '../students_providers.dart';
import 'padron_import.dart';
import 'padron_xlsx.dart';

/// Abre el panel de importación del padrón y refresca la lista al terminar.
Future<void> openPadronImport(BuildContext context, WidgetRef ref) async {
  final imported = await kiteSheet<bool>(
    context,
    title: 'Importar padrón',
    description:
        'Carga estudiantes desde un archivo CSV o Excel y los inscribe en una '
        'elección. Se identifican por código interno.',
    width: 620,
    body: const PadronImportSheet(),
  );
  if (imported == true) ref.invalidate(studentsProvider);
}

/// Módulo de importación: elegir elección, archivo, previsualizar e importar.
class PadronImportSheet extends ConsumerStatefulWidget {
  const PadronImportSheet({super.key});

  @override
  ConsumerState<PadronImportSheet> createState() => _PadronImportSheetState();
}

class _PadronImportSheetState extends ConsumerState<PadronImportSheet> {
  Election? _election;
  PadronImportBatch? _batch;
  String? _fileName;
  String? _error;
  bool _importing = false;
  bool _autoSelected = false;
  PadronImportOutcome? _outcome;

  static const XTypeGroup _fileTypes = XTypeGroup(
    label: 'Padrón (CSV o Excel)',
    extensions: <String>['csv', 'txt', 'xlsx'],
  );

  Future<void> _pickFile() async {
    final file = await openFile(acceptedTypeGroups: const [_fileTypes]);
    if (file == null) return;

    PadronImportBatch batch;
    try {
      if (file.name.toLowerCase().endsWith('.xlsx')) {
        batch = parsePadronXlsx(await file.readAsBytes());
      } else {
        batch = parsePadronCsv(await file.readAsString());
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo leer el archivo: $error');
      return;
    }
    if (!mounted) return;
    setState(() {
      _fileName = file.name;
      _batch = batch;
      _outcome = null;
      _error = null;
    });
  }

  Future<void> _import() async {
    final election = _election;
    final batch = _batch;
    if (election == null || batch == null || batch.rows.isEmpty) return;

    setState(() => _importing = true);
    try {
      final outcome = await ref
          .read(padronImportRepositoryProvider)
          .importPadron(electionId: election.id, rows: batch.rows);
      if (!mounted) return;
      setState(() {
        _outcome = outcome;
        _importing = false;
      });
      ref.invalidate(studentsProvider);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _error = _humanizeRpcError('$error');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = KiteText.of(context);
    final electionsAsync = ref.watch(electionsProvider);

    return electionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => KiteAlert(
        title: 'No se pudieron cargar las elecciones',
        description: '$error',
        tone: KiteTone.danger,
      ),
      data: (elections) {
        final importable = elections
            .where((e) => e.status == 'draft' || e.status == 'ready')
            .toList();

        if (_election == null && importable.isNotEmpty && !_autoSelected) {
          _autoSelected = true;
          final first = importable.first;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _election = first);
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (importable.isEmpty)
              const KiteAlert(
                title: 'No hay elecciones editables',
                description:
                    'Solo se puede importar el padrón de una elección en '
                    'borrador o lista (el padrón se congela al abrirla).',
                tone: KiteTone.warning,
              )
            else ...[
              KiteField(
                label: 'Elección',
                hint: 'El padrón solo se puede modificar antes de abrir.',
                child: KiteSelect<Election>(
                  options: importable,
                  labelOf: (e) =>
                      '${e.name} · ${electionStatusLabel(e.status)}',
                  value: _election,
                  placeholder: 'Selecciona una elección',
                  onChanged: (value) => setState(() {
                    _election = value;
                    _outcome = null;
                  }),
                ),
              ),
              const SizedBox(height: KiteSpace.md),
              _MesasHint(electionId: _election?.id),
              const SizedBox(height: KiteSpace.md),
              Row(
                children: [
                  KiteButton.outline(
                    onPressed: _importing ? null : _pickFile,
                    leading: const Icon(Icons.upload_file, size: 16),
                    child: const Text('Elegir archivo'),
                  ),
                  const SizedBox(width: KiteSpace.sm),
                  if (_fileName != null)
                    Expanded(child: Text(_fileName!, style: t.muted)),
                ],
              ),
              const SizedBox(height: KiteSpace.sm),
              Text(
                'Columnas admitidas: Código, Apellidos, Nombres, Cédula, Mesa, '
                'PIN, Fecha de nacimiento, Estado, Habilitado.',
                style: t.small,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: KiteSpace.lg),
              KiteAlert(
                title: 'No se pudo importar',
                description: _error,
                tone: KiteTone.danger,
              ),
            ],
            if (_batch != null) ...[
              const SizedBox(height: KiteSpace.lg),
              _BatchSummary(batch: _batch!),
              const SizedBox(height: KiteSpace.md),
              if (_batch!.hasRows) _PreviewTable(batch: _batch!),
              const SizedBox(height: KiteSpace.lg),
              KiteButton(
                enabled:
                    !_importing &&
                    _outcome == null &&
                    _election != null &&
                    _batch!.hasRows,
                onPressed: _import,
                leading: const Icon(Icons.cloud_upload, size: 16),
                child: Text(
                  _importing
                      ? 'Importando…'
                      : 'Importar ${_batch!.rows.length} filas',
                ),
              ),
            ],
            if (_outcome != null) ...[
              const SizedBox(height: KiteSpace.lg),
              _OutcomePanel(outcome: _outcome!),
              const SizedBox(height: KiteSpace.lg),
              KiteButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Listo'),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _MesasHint extends ConsumerWidget {
  const _MesasHint({required this.electionId});

  final String? electionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = electionId;
    if (id == null) return const SizedBox.shrink();
    final t = KiteText.of(context);
    final tablesAsync = ref.watch(electionTablesProvider(id));
    return tablesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (tables) {
        if (tables.isEmpty) return const SizedBox.shrink();
        return Text(
          'Mesas de la elección: ${tables.map((t) => t.code).join(', ')}',
          style: t.small,
        );
      },
    );
  }
}

class _BatchSummary extends StatelessWidget {
  const _BatchSummary({required this.batch});

  final PadronImportBatch batch;

  @override
  Widget build(BuildContext context) {
    final issues = batch.issues;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KiteAlert(
          title: '${batch.rows.length} filas listas para importar',
          description: issues.isEmpty
              ? 'No se detectaron problemas de formato.'
              : '${issues.length} líneas con problemas se omitirán:\n'
                    '${issues.take(10).map((i) => '· ${i.label}').join('\n')}'
                    '${issues.length > 10 ? '\n…' : ''}',
          tone: issues.isEmpty ? KiteTone.success : KiteTone.warning,
        ),
      ],
    );
  }
}

class _PreviewTable extends StatelessWidget {
  const _PreviewTable({required this.batch});

  final PadronImportBatch batch;

  @override
  Widget build(BuildContext context) {
    final preview = batch.rows.take(8).toList();
    return SizedBox(
      height: 220,
      child: KiteDataTable(
        paginate: false,
        columns: [
          trinaTextColumn('Código', 'code', width: 120),
          trinaTextColumn('Apellidos', 'last', width: 150),
          trinaTextColumn('Nombres', 'first', width: 150),
          trinaTextColumn('Cédula', 'cedula', width: 110),
          trinaTextColumn('Mesa', 'mesa', width: 100),
          trinaTextColumn('PIN', 'pin', width: 80),
        ],
        rows: [
          for (final row in preview)
            trinaRow({
              'code': row.internalCode,
              'last': row.lastName,
              'first': row.firstName,
              'cedula': row.cedula ?? '—',
              'mesa': row.tableCode ?? '—',
              'pin': row.pin == null ? '—' : '••••',
            }),
        ],
      ),
    );
  }
}

class _OutcomePanel extends StatelessWidget {
  const _OutcomePanel({required this.outcome});

  final PadronImportOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final hasErrors = outcome.errorCount > 0;
    return KiteAlert(
      title: 'Importación completada',
      description:
          '${outcome.created} creados, ${outcome.updated} actualizados, '
          '${outcome.assigned} en el padrón.'
          '${hasErrors ? '\n${outcome.errorCount} filas con error:\n'
                    '${outcome.errors.take(10).map((e) => '· ${e.label}').join('\n')}'
                    '${outcome.errors.length > 10 ? '\n…' : ''}' : ''}',
      tone: hasErrors ? KiteTone.warning : KiteTone.success,
    );
  }
}

String _humanizeRpcError(String raw) {
  if (raw.contains('padron_locked')) {
    return 'La elección ya no admite cambios en el padrón (está abierta o '
        'cerrada).';
  }
  if (raw.contains('not_allowed')) {
    return 'Tu cuenta no tiene permiso para importar el padrón.';
  }
  if (raw.contains('election_not_found')) {
    return 'La elección ya no existe.';
  }
  if (raw.contains('invalid_payload')) {
    return 'El archivo no produjo filas válidas.';
  }
  return raw;
}
