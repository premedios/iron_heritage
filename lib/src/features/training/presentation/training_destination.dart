import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/training_repository.dart';
import '../domain/training_models.dart';
import 'routine/routine_detail_screen.dart';
import 'routine/routine_editor_screen.dart';
import 'template/template_detail_screen.dart';
import 'template/template_editor_screen.dart';
import 'training_providers.dart';
import 'training_screen.dart';

final class TrainingDestination extends ConsumerWidget {
  const TrainingDestination({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(trainingRepositoryProvider);
    return TrainingScreen(
      onCreateTemplate: () => _openTemplateEditor(
        context,
        repository,
        WorkoutTemplateDraft(name: '', prescriptions: const []),
      ),
      onCreateRoutine: () => _openRoutineEditor(
        context,
        repository,
        RoutineDraft(name: '', templates: const []),
      ),
      onOpenTemplate: (id) => _openTemplateDetail(context, repository, id),
      onOpenRoutine: (id) => _openRoutineDetail(context, repository, id),
    );
  }

  Future<bool> _openTemplateEditor(
    BuildContext context,
    TrainingRepository repository,
    WorkoutTemplateDraft initial,
  ) async {
    var saved = false;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (routeContext) => TemplateEditorScreen.persisted(
          initial: initial,
          repository: repository,
          onSaved: (_) {
            saved = true;
            Navigator.of(routeContext).pop();
          },
        ),
      ),
    );
    return saved;
  }

  void _openTemplateDetail(
    BuildContext context,
    TrainingRepository repository,
    int templateId,
  ) {
    Navigator.of(
      context,
    ).push<void>(_templateDetailRoute(repository, templateId));
  }

  MaterialPageRoute<void> _templateDetailRoute(
    TrainingRepository repository,
    int templateId,
  ) {
    return MaterialPageRoute(
      builder: (routeContext) => TemplateDetailScreen(
        templateId: templateId,
        repository: repository,
        onStartWorkout: () => _showWorkoutUnavailable(routeContext),
        onEdit: (template) async {
          final saved = await _openTemplateEditor(
            routeContext,
            repository,
            template,
          );
          if (saved && routeContext.mounted) {
            await Navigator.of(routeContext).pushReplacement<void, void>(
              _templateDetailRoute(repository, templateId),
            );
          }
        },
        onArchived: () => Navigator.of(routeContext).pop(),
      ),
    );
  }

  Future<bool> _openRoutineEditor(
    BuildContext context,
    TrainingRepository repository,
    RoutineDraft initial,
  ) async {
    var saved = false;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (routeContext) => RoutineEditorScreen(
          initial: initial,
          repository: repository,
          onSaved: (_) {
            saved = true;
            Navigator.of(routeContext).pop();
          },
        ),
      ),
    );
    return saved;
  }

  void _openRoutineDetail(
    BuildContext context,
    TrainingRepository repository,
    int routineId,
  ) {
    Navigator.of(
      context,
    ).push<void>(_routineDetailRoute(repository, routineId));
  }

  MaterialPageRoute<void> _routineDetailRoute(
    TrainingRepository repository,
    int routineId,
  ) {
    return MaterialPageRoute(
      builder: (routeContext) => RoutineDetailScreen(
        routineId: routineId,
        repository: repository,
        onStartWorkout: (_) => _showWorkoutUnavailable(routeContext),
        onEdit: (routine) async {
          final saved = await _openRoutineEditor(
            routeContext,
            repository,
            routine,
          );
          if (saved && routeContext.mounted) {
            await Navigator.of(routeContext).pushReplacement<void, void>(
              _routineDetailRoute(repository, routineId),
            );
          }
        },
      ),
    );
  }

  void _showWorkoutUnavailable(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Workout tracking is not available yet')),
      );
  }
}
