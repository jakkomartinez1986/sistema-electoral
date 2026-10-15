import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../core/auth/auth_providers.dart';
import '../../shared/widgets/module_page.dart';
import '../../shared/widgets/table_helpers.dart';
import 'data/students_repository.dart';
import 'import/padron_import_sheet.dart';
import 'students_providers.dart';

/// Módulo D — Padrón estudiantil.
///
/// Registra y edita estudiantes, permite buscar, filtrar y habilitar o
/// deshabilitar su participación electoral. Nunca muestra el voto.
class PadronScreen extends ConsumerStatefulWidget {
  const PadronScreen({super.key});

  @override
  ConsumerState<PadronScreen> createState() => _PadronScreenState();
}

class _PadronScreenState extends ConsumerState<PadronScreen> {
  final _search = TextEditingController();
  String _status = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Student> _filter(List<Student> source) {
    final query = _search.text.trim().toLowerCase();
    return source.where((s) {
      if (_status.isNotEmpty && s.status != _status) return false;
      if (query.isEmpty) return true;
      return s.internalCode.toLowerCase().contains(query) ||
          s.firstName.toLowerCase().contains(query) ||
          s.lastName.toLowerCase().contains(query) ||
          (s.cedula ?? '').toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = KiteText.of(context);
    final institutionId = ref.watch(currentInstitutionIdProvider);
    final studentsAsync = ref.watch(studentsProvider);
    return ModulePage(
      title: 'Padrón estudiantil',
      description:
          'Datos mínimos del estudiante e identificadores internos. La '
          'habilitación electoral se controla por estudiante.',
      actions: [
        KiteButton.outline(
          enabled: institutionId != null,
          onPressed: institutionId == null
              ? null
              : () => openPadronImport(context, ref),
          leading: const Icon(Icons.upload_file, size: 16),
          child: const Text('Importar'),
        ),
        KiteButton.outline(
          onPressed: () => ref.invalidate(studentsProvider),
          leading: const Icon(Icons.refresh, size: 16),
          child: const Text('Actualizar'),
        ),
      ],
      child: studentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => KiteAlert(
          title: 'No se pudo cargar el padrón',
          description: '$error',
          tone: KiteTone.danger,
        ),
        data: (all) {
          final list = _filter(all);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: KiteInput(
                      controller: _search,
                      placeholder: 'Buscar por nombre, código o cédula',
                      leading: const Icon(Icons.search, size: 16),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: KiteSpace.md),
                  SizedBox(
                    width: 180,
                    child: KiteSelect<String>(
                      options: const ['', ...kStudentStatuses],
                      labelOf: (s) =>
                          s.isEmpty ? 'Todos' : studentStatusLabel(s),
                      value: _status,
                      onChanged: (value) =>
                          setState(() => _status = value ?? ''),
                    ),
                  ),
                  const SizedBox(width: KiteSpace.md),
                  KiteButton(
                    enabled: institutionId != null,
                    onPressed: institutionId == null
                        ? null
                        : () => _openStudentForm(
                            context,
                            ref,
                            institutionId,
                            null,
                          ),
                    leading: const Icon(Icons.add, size: 16),
                    child: const Text('Nuevo estudiante'),
                  ),
                ],
              ),
              const SizedBox(height: KiteSpace.sm),
              Text(
                '${list.length} de ${all.length} estudiantes',
                style: t.muted,
              ),
              const SizedBox(height: KiteSpace.sm),
              Expanded(
                child: list.isEmpty
                    ? const _EmptyState(
                        message:
                            'No hay estudiantes que coincidan. Ajusta el '
                            'buscador o registra uno nuevo.',
                      )
                    : KiteDataTable(
                        columns: [
                          trinaTextColumn('Código', 'code', width: 140),
                          trinaTextColumn('Apellidos', 'last', width: 180),
                          trinaTextColumn('Nombres', 'first', width: 180),
                          trinaTextColumn('Cédula', 'cedula', width: 140),
                          trinaTextColumn('Estado', 'status', width: 120),
                          trinaTextColumn('Habilitado', 'enabled', width: 120),
                        ],
                        rows: [
                          for (final s in list)
                            trinaRow({
                              'code': s.internalCode,
                              'last': s.lastName,
                              'first': s.firstName,
                              'cedula': s.cedula ?? '—',
                              'status': studentStatusLabel(s.status),
                              'enabled': s.enabled ? 'Sí' : 'No',
                            }),
                        ],
                        onRowTap: (index) => _openStudentForm(
                          context,
                          ref,
                          institutionId!,
                          list[index],
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final t = KiteText.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KiteSpace.xl),
        child: Text(message, style: t.muted, textAlign: TextAlign.center),
      ),
    );
  }
}

Future<void> _openStudentForm(
  BuildContext context,
  WidgetRef ref,
  String institutionId,
  Student? student,
) async {
  final saved = await kiteSheet<bool>(
    context,
    title: student == null ? 'Nuevo estudiante' : 'Editar estudiante',
    description: 'Datos mínimos e identificadores. Nunca se muestra el voto.',
    body: _StudentForm(institutionId: institutionId, student: student),
  );
  if (saved != true) return;
  ref.invalidate(studentsProvider);
  if (context.mounted) {
    KiteToast.show(
      context,
      title: student == null
          ? 'Estudiante registrado'
          : 'Estudiante actualizado',
      tone: KiteTone.success,
    );
  }
}

class _StudentForm extends ConsumerStatefulWidget {
  const _StudentForm({required this.institutionId, this.student});

  final String institutionId;
  final Student? student;

  @override
  ConsumerState<_StudentForm> createState() => _StudentFormState();
}

class _StudentFormState extends ConsumerState<_StudentForm> {
  late final TextEditingController _code;
  late final TextEditingController _first;
  late final TextEditingController _last;
  late final TextEditingController _cedula;
  final _pin = TextEditingController();
  DateTime? _birthDate;
  late String _status;
  late bool _enabled;
  bool _saving = false;
  bool? _hasPin;
  bool _pinBusy = false;

  @override
  void initState() {
    super.initState();
    final student = widget.student;
    _code = TextEditingController(text: student?.internalCode ?? '');
    _first = TextEditingController(text: student?.firstName ?? '');
    _last = TextEditingController(text: student?.lastName ?? '');
    _cedula = TextEditingController(text: student?.cedula ?? '');
    _birthDate = student?.birthDate;
    _status = student?.status ?? 'active';
    _enabled = student?.enabled ?? true;
    if (student != null) _loadPinStatus();
  }

  @override
  void dispose() {
    _code.dispose();
    _first.dispose();
    _last.dispose();
    _cedula.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _loadPinStatus() async {
    final student = widget.student;
    if (student == null) return;
    try {
      final has = await ref.read(studentsRepositoryProvider).hasPin(student.id);
      if (!mounted) return;
      setState(() => _hasPin = has);
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasPin = false);
    }
  }

  Future<void> _setPin() async {
    final student = widget.student;
    if (student == null) return;
    final pin = _pin.text.trim();
    if (!RegExp(r'^[0-9]{4,8}$').hasMatch(pin)) {
      KiteToast.show(
        context,
        title: 'El PIN debe tener de 4 a 8 dígitos',
        tone: KiteTone.danger,
      );
      return;
    }
    setState(() => _pinBusy = true);
    try {
      await ref.read(studentsRepositoryProvider).setStudentPin(student.id, pin);
      if (!mounted) return;
      _pin.clear();
      setState(() {
        _hasPin = true;
        _pinBusy = false;
      });
      KiteToast.show(
        context,
        title: 'PIN de votación actualizado',
        tone: KiteTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _pinBusy = false);
      KiteToast.show(
        context,
        title: 'No se pudo fijar el PIN',
        description: '$error',
        tone: KiteTone.danger,
      );
    }
  }

  Future<void> _clearPin() async {
    final student = widget.student;
    if (student == null) return;
    final confirmed = await kiteConfirm(
      context,
      title: 'Quitar PIN de votación',
      message:
          'El estudiante dejará de poder identificarse con PIN en la tablet. '
          'Podrá seguir usando su cédula si está registrada.',
      confirmLabel: 'Quitar',
      cancelLabel: 'Cancelar',
    );
    if (!confirmed) return;
    setState(() => _pinBusy = true);
    try {
      await ref.read(studentsRepositoryProvider).clearStudentPin(student.id);
      if (!mounted) return;
      setState(() {
        _hasPin = false;
        _pinBusy = false;
      });
      KiteToast.show(
        context,
        title: 'PIN de votación eliminado',
        tone: KiteTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _pinBusy = false);
      KiteToast.show(
        context,
        title: 'No se pudo quitar el PIN',
        description: '$error',
        tone: KiteTone.danger,
      );
    }
  }

  Future<void> _save() async {
    final code = _code.text.trim();
    final first = _first.text.trim();
    final last = _last.text.trim();
    if (code.isEmpty || first.isEmpty || last.isEmpty) {
      KiteToast.show(
        context,
        title: 'Código, nombres y apellidos son obligatorios',
        tone: KiteTone.danger,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(studentsRepositoryProvider);
      if (widget.student == null) {
        await repo.createStudent(
          institutionId: widget.institutionId,
          internalCode: code,
          firstName: first,
          lastName: last,
          cedula: _cedula.text,
          birthDate: _birthDate,
          status: _status,
          enabled: _enabled,
        );
      } else {
        await repo.updateStudent(
          widget.student!.id,
          internalCode: code,
          firstName: first,
          lastName: last,
          cedula: _cedula.text,
          birthDate: _birthDate,
          status: _status,
          enabled: _enabled,
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

  Future<void> _delete() async {
    final student = widget.student;
    if (student == null) return;
    final confirmed = await kiteConfirm(
      context,
      title: 'Eliminar estudiante',
      message:
          'Se eliminará a "${student.fullName}". No es posible si participa en '
          'una elección con historial.',
      confirmLabel: 'Eliminar',
    );
    if (!confirmed) return;
    try {
      await ref.read(studentsRepositoryProvider).deleteStudent(student.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      KiteToast.show(
        context,
        title: 'No se pudo eliminar',
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
          label: 'Código interno',
          hint: 'Identificador estable del colegio.',
          child: KiteInput(
            controller: _code,
            placeholder: 'Por ejemplo, 2025-0001',
          ),
        ),
        Row(
          children: [
            Expanded(
              child: KiteField(
                label: 'Apellidos',
                child: KiteInput(controller: _last),
              ),
            ),
            const SizedBox(width: KiteSpace.md),
            Expanded(
              child: KiteField(
                label: 'Nombres',
                child: KiteInput(controller: _first),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: KiteField(
                label: 'Cédula (opcional)',
                child: KiteInput(controller: _cedula),
              ),
            ),
            const SizedBox(width: KiteSpace.md),
            Expanded(
              child: KiteField(
                label: 'Fecha de nacimiento',
                child: KiteDatePicker(
                  selected: _birthDate,
                  placeholder: 'Opcional',
                  onChanged: (value) => setState(() => _birthDate = value),
                ),
              ),
            ),
          ],
        ),
        KiteField(
          label: 'Estado',
          child: KiteSelect<String>(
            options: kStudentStatuses,
            labelOf: studentStatusLabel,
            value: _status,
            onChanged: (value) => setState(() => _status = value ?? _status),
          ),
        ),
        KiteSwitch(
          value: _enabled,
          label: 'Habilitado para votar',
          sublabel: 'Desactívalo para excluirlo del padrón electoral.',
          onChanged: (value) => setState(() => _enabled = value),
        ),
        const Divider(height: KiteSpace.xl),
        _PinSection(
          hasPin: _hasPin,
          busy: _pinBusy,
          controller: _pin,
          onSet: widget.student == null ? null : _setPin,
          onClear: widget.student == null ? null : _clearPin,
        ),
        const SizedBox(height: KiteSpace.lg),
        Row(
          children: [
            if (widget.student != null)
              KiteButton.destructive(
                enabled: !_saving,
                onPressed: _delete,
                child: const Text('Eliminar'),
              ),
            const Spacer(),
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

/// Sección de PIN de votación dentro del formulario de estudiante.
class _PinSection extends StatelessWidget {
  const _PinSection({
    required this.hasPin,
    required this.busy,
    required this.controller,
    required this.onSet,
    required this.onClear,
  });

  final bool? hasPin;
  final bool busy;
  final TextEditingController controller;
  final VoidCallback? onSet;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final t = KiteText.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'PIN de votación',
              style: t.small.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: KiteSpace.sm),
            if (onSet == null)
              const KiteBadge('Guarda primero')
            else if (hasPin == null)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              KiteBadge(
                hasPin! ? 'Definido' : 'Sin PIN',
                tone: hasPin! ? KiteTone.success : KiteTone.warning,
              ),
          ],
        ),
        const SizedBox(height: KiteSpace.xs),
        Text(
          onSet == null
              ? 'Guarda el estudiante para poder definir su PIN.'
              : 'Permite identificar al votante en la tablet sin conexión. Se '
                    'guarda como hash; nunca en claro.',
          style: t.muted,
        ),
        if (onSet != null) ...[
          const SizedBox(height: KiteSpace.sm),
          Row(
            children: [
              Expanded(
                child: KiteInput(
                  controller: controller,
                  obscure: true,
                  keyboardType: TextInputType.number,
                  placeholder: 'Nuevo PIN (4 a 8 dígitos)',
                ),
              ),
              const SizedBox(width: KiteSpace.sm),
              KiteButton(
                enabled: !busy,
                onPressed: onSet,
                child: const Text('Fijar PIN'),
              ),
              if (hasPin == true) ...[
                const SizedBox(width: KiteSpace.sm),
                KiteButton.outline(
                  enabled: !busy,
                  onPressed: onClear,
                  child: const Text('Quitar'),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
