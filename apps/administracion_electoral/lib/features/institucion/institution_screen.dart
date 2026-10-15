import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../core/auth/auth_providers.dart';
import '../../shared/util/dates.dart';
import '../../shared/widgets/module_page.dart';
import 'data/institution_repository.dart';
import 'institution_providers.dart';

/// Módulo B — Institución y períodos electorales.
///
/// Gestiona los datos de la institución y los años lectivos. Los años lectivos
/// son la base sobre la que se organizan cursos, padrón y elecciones.
class InstitutionScreen extends ConsumerWidget {
  const InstitutionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ModulePage(
      title: 'Institución y períodos',
      description:
          'Datos de la institución y años lectivos. Los cambios se guardan en '
          'el backend y quedan sujetos a las políticas de acceso.',
      actions: [
        KiteButton.outline(
          onPressed: () {
            ref.invalidate(institutionProvider);
            ref.invalidate(academicYearsProvider);
          },
          leading: const Icon(Icons.refresh, size: 16),
          child: const Text('Actualizar'),
        ),
      ],
      child: ListView(
        padding: EdgeInsets.zero,
        children: const [
          _InstitutionSection(),
          SizedBox(height: KiteSpace.xl),
          _AcademicYearsSection(),
        ],
      ),
    );
  }
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: KiteSpace.xxl),
    child: Center(child: CircularProgressIndicator()),
  );
}

class _InstitutionSection extends ConsumerWidget {
  const _InstitutionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(institutionProvider);
    return async.when(
      loading: () => const _SectionLoading(),
      error: (error, _) => KiteAlert(
        title: 'No se pudo cargar la institución',
        description: '$error',
        tone: KiteTone.danger,
      ),
      data: (institution) {
        if (institution == null) {
          return const KiteAlert(
            title: 'Sin institución asignada',
            description:
                'Tu perfil de personal no tiene una institución asociada. '
                'Contacta a un administrador.',
            tone: KiteTone.warning,
          );
        }
        return KiteCard(
          title: 'Datos de la institución',
          trailing: KiteButton.outline(
            onPressed: () => _openInstitutionForm(context, ref, institution),
            child: const Text('Editar'),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DetailRow(label: 'Nombre', value: institution.name),
              DetailRow(label: 'Zona horaria', value: institution.timeZone),
              DetailRow(label: 'Identificador', value: institution.id),
            ],
          ),
        );
      },
    );
  }
}

class _AcademicYearsSection extends ConsumerWidget {
  const _AcademicYearsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = KiteText.of(context);
    final institutionId = ref.watch(currentInstitutionIdProvider);
    final years = ref.watch(academicYearsProvider);
    return KiteCard(
      title: 'Años lectivos',
      trailing: KiteButton(
        enabled: institutionId != null,
        onPressed: institutionId == null
            ? null
            : () => _openYearForm(context, ref, institutionId, null),
        leading: const Icon(Icons.add, size: 16),
        child: const Text('Nuevo año'),
      ),
      child: years.when(
        loading: () => const _SectionLoading(),
        error: (error, _) => KiteAlert(
          title: 'No se pudieron cargar los años lectivos',
          description: '$error',
          tone: KiteTone.danger,
        ),
        data: (list) {
          if (list.isEmpty) {
            return Text(
              'Aún no hay años lectivos registrados. Crea el primero para poder '
              'organizar cursos y elecciones.',
              style: t.muted,
            );
          }
          return Column(
            children: [
              for (final year in list)
                _AcademicYearRow(
                  year: year,
                  onEdit: () =>
                      _openYearForm(context, ref, year.institutionId, year),
                  onDelete: () => _deleteYear(context, ref, year),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AcademicYearRow extends StatelessWidget {
  const _AcademicYearRow({
    required this.year,
    required this.onEdit,
    required this.onDelete,
  });

  final AcademicYear year;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = KiteColors.of(context);
    final t = KiteText.of(context);
    final range = (year.startsOn == null && year.endsOn == null)
        ? 'Sin fechas'
        : '${year.startsOn == null ? '—' : dateOnly(year.startsOn!)} → '
              '${year.endsOn == null ? '—' : dateOnly(year.endsOn!)}';
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: KiteSpace.sm,
        horizontal: KiteSpace.sm,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              year.name,
              style: t.p.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(range, style: t.muted)),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 16),
            tooltip: 'Editar',
            color: c.mutedForeground,
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 16),
            tooltip: 'Eliminar',
            color: c.destructive,
          ),
        ],
      ),
    );
  }
}

Future<void> _openInstitutionForm(
  BuildContext context,
  WidgetRef ref,
  Institution institution,
) async {
  final saved = await kiteSheet<bool>(
    context,
    title: 'Editar institución',
    description:
        'Nombre y zona horaria con la que se registran fechas, horas y actas.',
    body: _InstitutionForm(institution: institution),
  );
  if (saved != true) return;
  ref.invalidate(institutionProvider);
  if (context.mounted) {
    KiteToast.show(
      context,
      title: 'Institución actualizada',
      tone: KiteTone.success,
    );
  }
}

Future<void> _openYearForm(
  BuildContext context,
  WidgetRef ref,
  String institutionId,
  AcademicYear? year,
) async {
  final saved = await kiteSheet<bool>(
    context,
    title: year == null ? 'Nuevo año lectivo' : 'Editar año lectivo',
    description: 'Nombre del período y sus fechas de inicio y fin.',
    body: _AcademicYearForm(institutionId: institutionId, year: year),
  );
  if (saved != true) return;
  ref.invalidate(academicYearsProvider);
  if (context.mounted) {
    KiteToast.show(
      context,
      title: year == null ? 'Año lectivo creado' : 'Año lectivo actualizado',
      tone: KiteTone.success,
    );
  }
}

Future<void> _deleteYear(
  BuildContext context,
  WidgetRef ref,
  AcademicYear year,
) async {
  final confirmed = await kiteConfirm(
    context,
    title: 'Eliminar año lectivo',
    message:
        'Se eliminará "${year.name}". No es posible si tiene cursos o '
        'elecciones asociadas.',
    confirmLabel: 'Eliminar',
  );
  if (!confirmed) return;
  try {
    await ref.read(institutionRepositoryProvider).deleteAcademicYear(year.id);
    ref.invalidate(academicYearsProvider);
    if (context.mounted) {
      KiteToast.show(
        context,
        title: 'Año lectivo eliminado',
        tone: KiteTone.success,
      );
    }
  } catch (error) {
    if (context.mounted) {
      KiteToast.show(
        context,
        title: 'No se pudo eliminar',
        description: '$error',
        tone: KiteTone.danger,
      );
    }
  }
}

class _InstitutionForm extends ConsumerStatefulWidget {
  const _InstitutionForm({required this.institution});

  final Institution institution;

  @override
  ConsumerState<_InstitutionForm> createState() => _InstitutionFormState();
}

class _InstitutionFormState extends ConsumerState<_InstitutionForm> {
  late final TextEditingController _name;
  late String _timeZone;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.institution.name);
    _timeZone = kTimeZones.contains(widget.institution.timeZone)
        ? widget.institution.timeZone
        : kTimeZones.first;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      KiteToast.show(
        context,
        title: 'El nombre no puede estar vacío',
        tone: KiteTone.danger,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(institutionRepositoryProvider)
          .updateInstitution(
            widget.institution.id,
            name: name,
            timeZone: _timeZone,
          );
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
          label: 'Nombre de la institución',
          child: KiteInput(
            controller: _name,
            placeholder: 'Unidad educativa',
          ),
        ),
        KiteField(
          label: 'Zona horaria institucional',
          hint: 'Se usa para fechas, horas y actas.',
          child: KiteSelect<String>(
            options: kTimeZones,
            labelOf: (zone) => zone,
            value: _timeZone,
            onChanged: (value) =>
                setState(() => _timeZone = value ?? _timeZone),
          ),
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

class _AcademicYearForm extends ConsumerStatefulWidget {
  const _AcademicYearForm({required this.institutionId, this.year});

  final String institutionId;
  final AcademicYear? year;

  @override
  ConsumerState<_AcademicYearForm> createState() => _AcademicYearFormState();
}

class _AcademicYearFormState extends ConsumerState<_AcademicYearForm> {
  late final TextEditingController _name;
  DateTime? _startsOn;
  DateTime? _endsOn;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.year?.name ?? '');
    _startsOn = widget.year?.startsOn;
    _endsOn = widget.year?.endsOn;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      KiteToast.show(
        context,
        title: 'El nombre del período no puede estar vacío',
        tone: KiteTone.danger,
      );
      return;
    }
    if (_startsOn != null && _endsOn != null && _startsOn!.isAfter(_endsOn!)) {
      KiteToast.show(
        context,
        title: 'La fecha de inicio no puede ser posterior al fin',
        tone: KiteTone.danger,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(institutionRepositoryProvider);
      if (widget.year == null) {
        await repo.createAcademicYear(
          institutionId: widget.institutionId,
          name: name,
          startsOn: _startsOn,
          endsOn: _endsOn,
        );
      } else {
        await repo.updateAcademicYear(
          widget.year!.id,
          name: name,
          startsOn: _startsOn,
          endsOn: _endsOn,
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
          label: 'Nombre del período',
          hint: 'Por ejemplo, "2025-2026".',
          child: KiteInput(controller: _name, placeholder: '2025-2026'),
        ),
        KiteField(
          label: 'Inicio',
          child: KiteDatePicker(
            selected: _startsOn,
            placeholder: 'Fecha de inicio',
            onChanged: (value) => setState(() => _startsOn = value),
          ),
        ),
        KiteField(
          label: 'Fin',
          child: KiteDatePicker(
            selected: _endsOn,
            placeholder: 'Fecha de fin',
            onChanged: (value) => setState(() => _endsOn = value),
          ),
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
