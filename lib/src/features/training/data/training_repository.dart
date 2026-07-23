import '../domain/training_models.dart';

final class DuplicateTrainingName implements Exception {
  const DuplicateTrainingName(this.field, this.message);

  final String field;
  final String message;
}

final class InvalidTrainingDraft implements Exception {
  const InvalidTrainingDraft(this.errors);

  final Map<String, String> errors;
}

abstract interface class TrainingRepository {
  Stream<List<WorkoutTemplateSummary>> watchTemplates({
    required bool archived,
    String query = '',
  });

  Future<WorkoutTemplateDraft?> loadTemplate(int id);
  Future<int> saveTemplate(WorkoutTemplateDraft draft);
  Future<ExercisePrescriptionDraft?> latestPrescription(int exerciseId);
  Future<void> setTemplateArchived(int id, {required bool archived});

  Stream<List<RoutineSummary>> watchRoutines({
    required bool archived,
    String query = '',
  });

  Future<RoutineDraft?> loadRoutine(int id);
  Future<int> saveRoutine(RoutineDraft draft);
  Future<int> saveRoutineTemplateAsStandalone(int templateId);
  Future<void> setRoutineArchived(int id, {required bool archived});
}
