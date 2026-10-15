import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../shared/widgets/module_page.dart';
import '../../shared/widgets/table_helpers.dart';
import '../institucion/institution_providers.dart';
import 'courses_providers.dart';
import 'data/courses_repository.dart';

/// Módulo C — Cursos y mesas.
///
/// Los cursos pertenecen a un año lectivo. Las mesas pertenecen a una elección;
/// aquí se muestran en modo lectura y se crean en el módulo Elecciones.
class CoursesScreen extends ConsumerStatefulWidget {
  const CoursesScreen({super.key});

  @override
  ConsumerState<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends ConsumerState<CoursesScreen> {
  String? _yearId;
  bool _showTables = false;

  @override
  Widget build(BuildContext context) {
    final yearsAsync = ref.watch(academicYearsProvider);
    return ModulePage(
      title: 'Cursos y mesas',
      description:
          'Grados, paralelos y tutores por año lectivo. Las mesas se crean en '
          'el módulo Elecciones y aquí se consultan.',
      actions: [
        KiteButton.outline(
          onPressed: () {
            ref.invalidate(academicYearsProvider);
            ref.invalidate(tutorsProvider);
            if (_yearId != null) {
              ref.invalidate(coursesProvider(_yearId!));
              ref.invalidate(votingTablesProvider(_yearId!));
            }
          },
          leading: const Icon(Icons.refresh, size: 16),
          child: const Text('Actualizar'),
        ),
      ],
      child: yearsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => KiteAlert(
          title: 'No se pudieron cargar los años lectivos',
          description: '$error',
          tone: KiteTone.danger,
        ),
        data: (years) {
          if (years.isEmpty) {
            return const KiteAlert(
              title: 'Sin años lectivos',
              description:
                  'Crea un año lectivo en el módulo "Institución y períodos" '
                  'antes de registrar cursos.',
              tone: KiteTone.warning,
            );
          }
          final byId = {for (final y in years) y.id: y};
          final effectiveId =
              (_yearId != null && byId.containsKey(_yearId))
              ? _yearId!
              : years.first.id;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 260,
                    child: KiteSelect<String>(
                      options: [for (final y in years) y.id],
                      labelOf: (id) => byId[id]!.name,
                      value: effectiveId,
                      placeholder: 'Año lectivo',
                      onChanged: (value) =>
                          setState(() => _yearId = value ?? effectiveId),
                    ),
                  ),
                  const Spacer(),
                  _SegmentedToggle(
                    labels: const ['Cursos', 'Mesas'],
                    index: _showTables ? 1 : 0,
                    onChanged: (i) => setState(() => _showTables = i == 1),
                  ),
                ],
              ),
              const SizedBox(height: KiteSpace.lg),
              Expanded(
                child: _showTables
                    ? _TablesTab(academicYearId: effectiveId)
                    : _CoursesTab(academicYearId: effectiveId),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SegmentedToggle extends StatelessWidget {
  const _SegmentedToggle({
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = KiteColors.of(context);
    final t = KiteText.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: c.border),
        borderRadius: KiteRadius.allMd,
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++)
            Material(
              color: i == index ? c.accent : Colors.transparent,
              borderRadius: KiteRadius.allSm,
              child: InkWell(
                borderRadius: KiteRadius.allSm,
                onTap: () => onChanged(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KiteSpace.md,
                    vertical: 6,
                  ),
                  child: Text(
                    labels[i],
                    style: t.small.copyWith(
                      fontWeight: i == index
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: i == index ? c.foreground : c.mutedForeground,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CoursesTab extends ConsumerWidget {
  const _CoursesTab({required this.academicYearId});

  final String academicYearId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = KiteText.of(context);
    final coursesAsync = ref.watch(coursesProvider(academicYearId));
    final tutors = ref.watch(tutorsProvider).value ?? const <StaffOption>[];
    final tutorName = {for (final s in tutors) s.id: s.fullName};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '${coursesAsync.value?.length ?? 0} cursos',
              style: t.muted,
            ),
            const Spacer(),
            KiteButton(
              onPressed: () =>
                  _openCourseForm(context, ref, academicYearId, null),
              leading: const Icon(Icons.add, size: 16),
              child: const Text('Nuevo curso'),
            ),
          ],
        ),
        const SizedBox(height: KiteSpace.sm),
        Expanded(
          child: coursesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => KiteAlert(
              title: 'No se pudieron cargar los cursos',
              description: '$error',
              tone: KiteTone.danger,
            ),
            data: (list) {
              if (list.isEmpty) {
                return const _EmptyState(
                  message:
                      'Aún no hay cursos en este año lectivo. Crea el primero '
                      'con "Nuevo curso".',
                );
              }
              return KiteDataTable(
                columns: [
                  trinaTextColumn('Grado', 'grade', width: 120),
                  trinaTextColumn('Paralelo', 'parallel', width: 120),
                  trinaTextColumn('Nombre', 'display_name', width: 200),
                  trinaTextColumn('Tutor', 'tutor', width: 220),
                ],
                rows: [
                  for (final course in list)
                    trinaRow({
                      'grade': course.grade,
                      'parallel': course.parallel,
                      'display_name': course.displayName,
                      'tutor': course.tutorProfileId == null
                          ? 'Sin asignar'
                          : (tutorName[course.tutorProfileId] ?? '—'),
                    }),
                ],
                onRowTap: (index) =>
                    _openCourseForm(context, ref, academicYearId, list[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TablesTab extends ConsumerWidget {
  const _TablesTab({required this.academicYearId});

  final String academicYearId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = KiteText.of(context);
    final tablesAsync = ref.watch(votingTablesProvider(academicYearId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Las mesas se crean y asignan en el módulo Elecciones. Aquí solo se '
          'consultan.',
          style: t.muted,
        ),
        const SizedBox(height: KiteSpace.sm),
        Expanded(
          child: tablesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => KiteAlert(
              title: 'No se pudieron cargar las mesas',
              description: '$error',
              tone: KiteTone.danger,
            ),
            data: (list) {
              if (list.isEmpty) {
                return const _EmptyState(
                  message:
                      'No hay mesas en este año lectivo. Se crean al configurar '
                      'una elección.',
                );
              }
              return KiteDataTable(
                columns: [
                  trinaTextColumn('Mesa', 'code', width: 120),
                  trinaTextColumn('Nombre', 'name', width: 200),
                  trinaTextColumn(
                    'Capacidad',
                    'capacity',
                    width: 120,
                    align: TrinaColumnTextAlign.right,
                  ),
                  trinaTextColumn('Elección', 'election', width: 240),
                ],
                rows: [
                  for (final table in list)
                    trinaRow({
                      'code': table.code,
                      'name': table.name ?? '—',
                      'capacity': table.capacity == null
                          ? '—'
                          : '${table.capacity}',
                      'election': table.electionName,
                    }),
                ],
              );
            },
          ),
        ),
      ],
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

Future<void> _openCourseForm(
  BuildContext context,
  WidgetRef ref,
  String academicYearId,
  Course? course,
) async {
  final saved = await kiteSheet<bool>(
    context,
    title: course == null ? 'Nuevo curso' : 'Editar curso',
    description: 'Grado, paralelo y tutor responsable.',
    body: _CourseForm(academicYearId: academicYearId, course: course),
  );
  if (saved != true) return;
  ref.invalidate(coursesProvider(academicYearId));
  if (context.mounted) {
    KiteToast.show(
      context,
      title: course == null ? 'Curso creado' : 'Curso actualizado',
      tone: KiteTone.success,
    );
  }
}

class _CourseForm extends ConsumerStatefulWidget {
  const _CourseForm({required this.academicYearId, this.course});

  final String academicYearId;
  final Course? course;

  @override
  ConsumerState<_CourseForm> createState() => _CourseFormState();
}

class _CourseFormState extends ConsumerState<_CourseForm> {
  late final TextEditingController _grade;
  late final TextEditingController _parallel;
  late final TextEditingController _displayName;
  String? _tutorId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final course = widget.course;
    _grade = TextEditingController(text: course?.grade ?? '');
    _parallel = TextEditingController(text: course?.parallel ?? '');
    _displayName = TextEditingController(text: course?.displayName ?? '');
    _tutorId = course?.tutorProfileId;
  }

  @override
  void dispose() {
    _grade.dispose();
    _parallel.dispose();
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final grade = _grade.text.trim();
    final parallel = _parallel.text.trim();
    final displayName = _displayName.text.trim();
    if (grade.isEmpty || parallel.isEmpty || displayName.isEmpty) {
      KiteToast.show(
        context,
        title: 'Grado, paralelo y nombre son obligatorios',
        tone: KiteTone.danger,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(coursesRepositoryProvider);
      if (widget.course == null) {
        await repo.createCourse(
          academicYearId: widget.academicYearId,
          grade: grade,
          parallel: parallel,
          displayName: displayName,
          tutorProfileId: _tutorId,
        );
      } else {
        await repo.updateCourse(
          widget.course!.id,
          grade: grade,
          parallel: parallel,
          displayName: displayName,
          tutorProfileId: _tutorId,
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
    final course = widget.course;
    if (course == null) return;
    final confirmed = await kiteConfirm(
      context,
      title: 'Eliminar curso',
      message:
          'Se eliminará "${course.displayName}". No es posible si tiene mesas '
          'o padrón asociados.',
      confirmLabel: 'Eliminar',
    );
    if (!confirmed) return;
    try {
      await ref.read(coursesRepositoryProvider).deleteCourse(course.id);
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
    final tutorsAsync = ref.watch(tutorsProvider);
    final tutors = tutorsAsync.value ?? const <StaffOption>[];
    final options = <StaffOption>[
      const StaffOption(id: '', fullName: 'Sin tutor asignado'),
      ...tutors,
    ];
    final hasTutor = options.any((o) => o.id == (_tutorId ?? ''));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KiteField(
          label: 'Grado',
          child: KiteInput(
            controller: _grade,
            placeholder: 'Por ejemplo, "10" o "3ro BGU"',
          ),
        ),
        KiteField(
          label: 'Paralelo',
          child: KiteInput(controller: _parallel, placeholder: 'Por ejemplo, "A"'),
        ),
        KiteField(
          label: 'Nombre para mostrar',
          child: KiteInput(
            controller: _displayName,
            placeholder: 'Por ejemplo, "10mo A"',
          ),
        ),
        KiteField(
          label: 'Tutor responsable',
          child: KiteSelect<StaffOption>(
            options: options,
            labelOf: (o) => o.fullName,
            value: hasTutor
                ? options.firstWhere((o) => o.id == (_tutorId ?? ''))
                : null,
            placeholder: 'Selecciona un tutor',
            onChanged: (value) => setState(
              () => _tutorId = (value == null || value.id.isEmpty)
                  ? null
                  : value.id,
            ),
          ),
        ),
        const SizedBox(height: KiteSpace.lg),
        Row(
          children: [
            if (widget.course != null)
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
