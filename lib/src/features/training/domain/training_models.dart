enum PlannedSetType { working, dropset }

final class PlannedSetDraft {
  const PlannedSetDraft({
    this.id,
    this.weight,
    this.minReps,
    this.maxReps,
    this.rir,
    this.type = PlannedSetType.working,
  });

  final int? id;
  final double? weight;
  final int? minReps;
  final int? maxReps;
  final int? rir;
  final PlannedSetType type;

  PlannedSetDraft deepCopy() => PlannedSetDraft(
    weight: weight,
    minReps: minReps,
    maxReps: maxReps,
    rir: rir,
    type: type,
  );
}

final class ExercisePrescriptionDraft {
  const ExercisePrescriptionDraft({
    this.id,
    required this.exerciseId,
    required this.exerciseName,
    this.notes,
    required this.plannedSets,
  });

  final int? id;
  final int exerciseId;
  final String exerciseName;
  final String? notes;
  final List<PlannedSetDraft> plannedSets;

  ExercisePrescriptionDraft deepCopy() => ExercisePrescriptionDraft(
    exerciseId: exerciseId,
    exerciseName: exerciseName,
    notes: notes,
    plannedSets: plannedSets.map((set) => set.deepCopy()).toList(),
  );
}

final class WorkoutTemplateDraft {
  const WorkoutTemplateDraft({
    this.id,
    this.routineId,
    this.archivedAt,
    required this.name,
    required this.prescriptions,
  });

  final int? id;
  final int? routineId;
  final DateTime? archivedAt;
  final String name;
  final List<ExercisePrescriptionDraft> prescriptions;

  WorkoutTemplateDraft deepCopy({int? routineId}) => WorkoutTemplateDraft(
    routineId: routineId,
    name: name,
    prescriptions: prescriptions.map((item) => item.deepCopy()).toList(),
  );
}

final class RoutineDraft {
  const RoutineDraft({
    this.id,
    this.archivedAt,
    required this.name,
    required this.templates,
  });

  final int? id;
  final DateTime? archivedAt;
  final String name;
  final List<WorkoutTemplateDraft> templates;
}

final class ExerciseChoice {
  const ExerciseChoice({required this.id, required this.name});

  final int id;
  final String name;
}

final class WorkoutTemplateSummary {
  const WorkoutTemplateSummary({
    required this.id,
    required this.name,
    required this.exerciseNames,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final List<String> exerciseNames;
  final DateTime updatedAt;
}

final class RoutineSummary {
  const RoutineSummary({
    required this.id,
    required this.name,
    required this.templateNames,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final List<String> templateNames;
  final DateTime updatedAt;
}
