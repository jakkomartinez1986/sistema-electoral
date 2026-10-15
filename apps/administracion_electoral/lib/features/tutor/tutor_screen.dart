import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../core/auth/auth_providers.dart';
import '../../shared/widgets/table_helpers.dart';
import 'data/tutor_repository.dart';
import 'tutor_providers.dart';

/// Vista de solo lectura para un tutor.
///
/// Un tutor no administra la elección: consulta los cursos que tiene asignados y
/// los estudiantes de esos cursos (con su mesa), pero no puede crear ni editar
/// nada. El ámbito lo impone el backend a través de `get_tutor_scope`.
class TutorScreen extends ConsumerWidget {
  const TutorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _TutorTopBar(),
            Expanded(child: _TutorBody()),
          ],
        ),
      ),
    );
  }
}

class _TutorTopBar extends ConsumerWidget {
  const _TutorTopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = KiteColors.of(context);
    final t = KiteText.of(context);
    final profile = ref.watch(authControllerProvider).value;
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: c.card,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: KiteSpace.xl),
      child: Row(
        children: [
          Icon(Icons.school_outlined, color: c.primary, size: 22),
          const SizedBox(width: KiteSpace.sm),
          Text('Mi área como tutor', style: t.h4),
          const Spacer(),
          if (profile != null) ...[
            Text(
              profile.fullName,
              style: t.small.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: KiteSpace.md),
            KiteButton.ghost(
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).signOut(),
              leading: const Icon(Icons.logout, size: 16),
              child: const Text('Salir'),
            ),
          ],
        ],
      ),
    );
  }
}

class _TutorBody extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = KiteText.of(context);
    final scopeAsync = ref.watch(tutorScopeProvider);
    return Padding(
      padding: const EdgeInsets.all(KiteSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mis cursos y estudiantes', style: t.h3),
                    const SizedBox(height: KiteSpace.xs),
                    Text(
                      'Consulta de solo lectura. Solo ves los cursos que tienes '
                      'asignados y los estudiantes de esos cursos.',
                      style: t.muted,
                    ),
                  ],
                ),
              ),
              KiteButton.outline(
                onPressed: () => ref.invalidate(tutorScopeProvider),
                leading: const Icon(Icons.refresh, size: 16),
                child: const Text('Actualizar'),
              ),
            ],
          ),
          const SizedBox(height: KiteSpace.lg),
          Expanded(
            child: scopeAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => KiteAlert(
                title: 'No se pudo cargar tu ámbito',
                description: '$error',
                tone: KiteTone.danger,
              ),
              data: (scope) {
                if (scope.courses.isEmpty) {
                  return const KiteAlert(
                    title: 'Sin cursos asignados',
                    description:
                        'Todavía no tienes cursos asignados como tutor. Pide a '
                        'un administrador que te asigne uno.',
                    tone: KiteTone.warning,
                  );
                }
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final course in scope.courses) ...[
                        _CourseCard(
                          course: course,
                          students: scope.studentsOf(course.id),
                        ),
                        const SizedBox(height: KiteSpace.lg),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course, required this.students});

  final TutorCourse course;
  final List<TutorStudent> students;

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
              Icon(Icons.groups_outlined, size: 18, color: c.primary),
              const SizedBox(width: KiteSpace.sm),
              Text(course.displayName, style: t.h4),
              const SizedBox(width: KiteSpace.md),
              KiteBadge(
                '${students.length} '
                '${students.length == 1 ? 'estudiante' : 'estudiantes'}',
              ),
            ],
          ),
          const SizedBox(height: KiteSpace.md),
          if (students.isEmpty)
            Text('Aún no hay estudiantes en el padrón de este curso.', style: t.muted)
          else
            SizedBox(
              height: 44 + students.length * 46 + 2,
              child: KiteDataTable(
                paginate: false,
                columns: [
                  trinaTextColumn('Estudiante', 'student', width: 220),
                  trinaTextColumn('Código', 'code', width: 140),
                  trinaTextColumn('Cédula', 'cedula', width: 140),
                  trinaTextColumn('Mesa', 'table', width: 110),
                  trinaTextColumn('Elección', 'election', width: 260),
                  trinaTextColumn('Estado', 'status', width: 140),
                ],
                rows: [
                  for (final s in students)
                    trinaRow({
                      'student': s.fullName,
                      'code': s.internalCode,
                      'cedula': s.cedula ?? '—',
                      'table': s.votingTableCode ?? '—',
                      'election': s.electionName,
                      'status': s.enabled ? 'Habilitado' : 'Deshabilitado',
                    }),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
