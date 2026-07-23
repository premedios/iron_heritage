import 'dart:async';

import 'package:iron_heritage/src/features/training/data/training_repository.dart';
import 'package:iron_heritage/src/features/training/domain/training_models.dart';

final class FakeTrainingRepository implements TrainingRepository {
  FakeTrainingRepository({
    List<WorkoutTemplateSummary> templates = const [],
    List<RoutineSummary> routines = const [],
  }) : _templates = List.of(templates),
       _routines = List.of(routines);

  final latestByExercise = <int, ExercisePrescriptionDraft>{};
  final templateDraftsById = <int, WorkoutTemplateDraft>{};
  final routineDraftsById = <int, RoutineDraft>{};
  final savedTemplates = <WorkoutTemplateDraft>[];
  final savedRoutines = <RoutineDraft>[];
  final copiedRoutineTemplateIds = <int>[];
  final archivedTemplateIds = <int>[];
  final restoredTemplateIds = <int>[];
  final archivedRoutineIds = <int>[];
  final restoredRoutineIds = <int>[];
  final templateArchiveCalls = <({int id, bool archived})>[];
  final routineArchiveCalls = <({int id, bool archived})>[];

  Object? saveError;
  Object? routineSaveError;
  Object? templateWatchError;
  Object? routineWatchError;
  bool templateWatchPending = false;
  bool routineWatchPending = false;
  int templateWatchSubscriptions = 0;
  int templateWatchCancellations = 0;
  int routineWatchSubscriptions = 0;
  int routineWatchCancellations = 0;

  final _templateChanges = StreamController<void>.broadcast();
  final _routineChanges = StreamController<void>.broadcast();
  final _archivedTemplates = <WorkoutTemplateSummary>[];
  final _archivedRoutines = <RoutineSummary>[];
  List<WorkoutTemplateSummary> _templates;
  List<RoutineSummary> _routines;
  int _nextTemplateId = 1000;
  int _nextRoutineId = 1000;

  @override
  Stream<List<WorkoutTemplateSummary>> watchTemplates({
    required bool archived,
    String query = '',
  }) {
    return Stream.multi((controller) {
      templateWatchSubscriptions++;
      controller.onCancel = () {
        templateWatchCancellations++;
      };
      if (templateWatchPending) {
        return;
      }
      final initialError = templateWatchError;
      if (initialError != null) {
        controller
          ..addError(initialError)
          ..close();
        return;
      }
      controller.add(_filteredTemplates(archived: archived, query: query));
      final subscription = _templateChanges.stream.listen((_) {
        final error = templateWatchError;
        if (error != null) {
          controller
            ..addError(error)
            ..close();
          return;
        }
        controller.add(_filteredTemplates(archived: archived, query: query));
      });
      controller.onCancel = () async {
        templateWatchCancellations++;
        await subscription.cancel();
      };
    });
  }

  @override
  Future<WorkoutTemplateDraft?> loadTemplate(int id) async {
    return templateDraftsById[id];
  }

  @override
  Future<int> saveTemplate(WorkoutTemplateDraft draft) async {
    savedTemplates.add(draft);
    final error = saveError;
    if (error != null) {
      throw error;
    }
    final id = draft.id ?? _nextTemplateId++;
    templateDraftsById[id] = draft;
    return id;
  }

  @override
  Future<ExercisePrescriptionDraft?> latestPrescription(int exerciseId) async {
    return latestByExercise[exerciseId]?.deepCopy();
  }

  @override
  Future<void> setTemplateArchived(int id, {required bool archived}) async {
    templateArchiveCalls.add((id: id, archived: archived));
    if (archived) {
      archivedTemplateIds.add(id);
      _moveTemplate(id, from: _templates, to: _archivedTemplates);
    } else {
      restoredTemplateIds.add(id);
      _moveTemplate(id, from: _archivedTemplates, to: _templates);
    }
    _templateChanges.add(null);
  }

  @override
  Stream<List<RoutineSummary>> watchRoutines({
    required bool archived,
    String query = '',
  }) {
    return Stream.multi((controller) {
      routineWatchSubscriptions++;
      controller.onCancel = () {
        routineWatchCancellations++;
      };
      if (routineWatchPending) {
        return;
      }
      final initialError = routineWatchError;
      if (initialError != null) {
        controller
          ..addError(initialError)
          ..close();
        return;
      }
      controller.add(_filteredRoutines(archived: archived, query: query));
      final subscription = _routineChanges.stream.listen((_) {
        final error = routineWatchError;
        if (error != null) {
          controller
            ..addError(error)
            ..close();
          return;
        }
        controller.add(_filteredRoutines(archived: archived, query: query));
      });
      controller.onCancel = () async {
        routineWatchCancellations++;
        await subscription.cancel();
      };
    });
  }

  @override
  Future<RoutineDraft?> loadRoutine(int id) async {
    return routineDraftsById[id];
  }

  @override
  Future<int> saveRoutine(RoutineDraft draft) async {
    savedRoutines.add(draft);
    final error = routineSaveError;
    if (error != null) {
      throw error;
    }
    final id = draft.id ?? _nextRoutineId++;
    routineDraftsById[id] = draft;
    return id;
  }

  @override
  Future<int> saveRoutineTemplateAsStandalone(int templateId) async {
    copiedRoutineTemplateIds.add(templateId);
    final error = saveError;
    if (error != null) {
      throw error;
    }
    return _nextTemplateId++;
  }

  @override
  Future<void> setRoutineArchived(int id, {required bool archived}) async {
    routineArchiveCalls.add((id: id, archived: archived));
    if (archived) {
      archivedRoutineIds.add(id);
      _moveRoutine(id, from: _routines, to: _archivedRoutines);
    } else {
      restoredRoutineIds.add(id);
      _moveRoutine(id, from: _archivedRoutines, to: _routines);
    }
    _routineChanges.add(null);
  }

  void emitTemplates(List<WorkoutTemplateSummary> templates) {
    _templates = List.of(templates);
    _templateChanges.add(null);
  }

  void emitRoutines(List<RoutineSummary> routines) {
    _routines = List.of(routines);
    _routineChanges.add(null);
  }

  Future<void> dispose() async {
    await _templateChanges.close();
    await _routineChanges.close();
  }

  List<WorkoutTemplateSummary> _filteredTemplates({
    required bool archived,
    required String query,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final source = archived ? _archivedTemplates : _templates;
    return source
        .where(
          (summary) =>
              summary.name.toLowerCase().contains(normalizedQuery) ||
              summary.exerciseNames.any(
                (name) => name.toLowerCase().contains(normalizedQuery),
              ),
        )
        .toList()
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
  }

  List<RoutineSummary> _filteredRoutines({
    required bool archived,
    required String query,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final source = archived ? _archivedRoutines : _routines;
    return source
        .where(
          (summary) =>
              summary.name.toLowerCase().contains(normalizedQuery) ||
              summary.templateNames.any(
                (name) => name.toLowerCase().contains(normalizedQuery),
              ),
        )
        .toList()
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
  }

  static void _moveTemplate(
    int id, {
    required List<WorkoutTemplateSummary> from,
    required List<WorkoutTemplateSummary> to,
  }) {
    final index = from.indexWhere((summary) => summary.id == id);
    if (index != -1) {
      to.add(from.removeAt(index));
    }
  }

  static void _moveRoutine(
    int id, {
    required List<RoutineSummary> from,
    required List<RoutineSummary> to,
  }) {
    final index = from.indexWhere((summary) => summary.id == id);
    if (index != -1) {
      to.add(from.removeAt(index));
    }
  }
}
