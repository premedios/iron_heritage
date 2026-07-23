import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import '../domain/training_models.dart';
import '../domain/training_validation.dart';
import 'training_repository.dart';

final class DriftTrainingRepository implements TrainingRepository {
  DriftTrainingRepository(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  @override
  Stream<List<WorkoutTemplateSummary>> watchTemplates({
    required bool archived,
    String query = '',
  }) {
    final statement = _db.select(_db.workoutTemplates).join([
      leftOuterJoin(
        _db.exercisePrescriptions,
        _db.exercisePrescriptions.templateId.equalsExp(_db.workoutTemplates.id),
      ),
      leftOuterJoin(
        _db.exercises,
        _db.exercises.id.equalsExp(_db.exercisePrescriptions.exerciseId),
      ),
    ]);
    statement
      ..where(
        _db.workoutTemplates.routineId.isNull() &
            (archived
                ? _db.workoutTemplates.archivedAt.isNotNull()
                : _db.workoutTemplates.archivedAt.isNull()),
      )
      ..orderBy([
        OrderingTerm.desc(_db.workoutTemplates.updatedAt),
        OrderingTerm.asc(_db.exercisePrescriptions.position),
      ]);

    final normalizedQuery = TrainingValidation.normalizeName(query);
    return statement.watch().map((rows) {
      final summaries = <int, WorkoutTemplateSummary>{};
      for (final row in rows) {
        final template = row.readTable(_db.workoutTemplates);
        final exercise = row.readTableOrNull(_db.exercises);
        final existing = summaries[template.id];
        summaries[template.id] = WorkoutTemplateSummary(
          id: template.id,
          name: template.name,
          exerciseNames: [
            ...?existing?.exerciseNames,
            if (exercise != null) exercise.name,
          ],
          updatedAt: template.updatedAt,
        );
      }

      return summaries.values
          .where(
            (summary) =>
                TrainingValidation.normalizeName(
                  summary.name,
                ).contains(normalizedQuery) ||
                summary.exerciseNames.any(
                  (name) => TrainingValidation.normalizeName(
                    name,
                  ).contains(normalizedQuery),
                ),
          )
          .toList()
        ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    });
  }

  @override
  Future<WorkoutTemplateDraft?> loadTemplate(int id) async {
    final template = await (_db.select(
      _db.workoutTemplates,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (template == null) {
      return null;
    }

    return WorkoutTemplateDraft(
      id: template.id,
      routineId: template.routineId,
      archivedAt: template.archivedAt,
      name: template.name,
      prescriptions: await _loadPrescriptions(template.id),
    );
  }

  @override
  Future<int> saveTemplate(WorkoutTemplateDraft draft) async {
    final structuralErrors = TrainingValidation.template(draft);
    if (structuralErrors.isNotEmpty) {
      throw InvalidTrainingDraft(structuralErrors);
    }
    await _assertTemplateNameAvailable(draft);

    return _db.transaction(() async {
      final timestamp = _now();
      final templateId = draft.id == null
          ? await _db
                .into(_db.workoutTemplates)
                .insert(
                  WorkoutTemplatesCompanion.insert(
                    name: draft.name.trim(),
                    routineId: Value(draft.routineId),
                    position: const Value.absent(),
                    createdAt: Value(timestamp),
                    updatedAt: Value(timestamp),
                  ),
                )
          : draft.id!;
      if (draft.id != null) {
        await (_db.update(
          _db.workoutTemplates,
        )..where((row) => row.id.equals(templateId))).write(
          WorkoutTemplatesCompanion(
            name: Value(draft.name.trim()),
            updatedAt: Value(timestamp),
          ),
        );
      }
      await _replacePrescriptions(templateId, draft.prescriptions, timestamp);
      return templateId;
    });
  }

  @override
  Future<ExercisePrescriptionDraft?> latestPrescription(int exerciseId) async {
    final prescription =
        await (_db.select(_db.exercisePrescriptions)
              ..where((row) => row.exerciseId.equals(exerciseId))
              ..orderBy([
                (row) => OrderingTerm.desc(row.updatedAt),
                (row) => OrderingTerm.desc(row.id),
              ])
              ..limit(1))
            .getSingleOrNull();
    if (prescription == null) {
      return null;
    }

    final exercise = await (_db.select(
      _db.exercises,
    )..where((row) => row.id.equals(exerciseId))).getSingle();
    final draft = ExercisePrescriptionDraft(
      id: prescription.id,
      exerciseId: prescription.exerciseId,
      exerciseName: exercise.name,
      notes: prescription.notes,
      plannedSets: await _loadPlannedSets(prescription.id),
    );
    return draft.deepCopy();
  }

  @override
  Future<void> setTemplateArchived(int id, {required bool archived}) async {
    final template =
        await (_db.select(_db.workoutTemplates)
              ..where((row) => row.id.equals(id) & row.routineId.isNull()))
            .getSingleOrNull();
    if (template == null) {
      throw StateError('Standalone Template not found');
    }
    if (!archived) {
      await _assertTemplateNameAvailable(
        WorkoutTemplateDraft(
          id: template.id,
          name: template.name,
          prescriptions: const [],
        ),
      );
    }

    final timestamp = _now();
    await (_db.update(
      _db.workoutTemplates,
    )..where((row) => row.id.equals(id) & row.routineId.isNull())).write(
      WorkoutTemplatesCompanion(
        archivedAt: Value(archived ? timestamp : null),
        updatedAt: Value(timestamp),
      ),
    );
  }

  Future<void> _assertTemplateNameAvailable(WorkoutTemplateDraft draft) async {
    if (draft.routineId != null) {
      return;
    }
    final normalizedName = TrainingValidation.normalizeName(draft.name);
    final standaloneTemplates = await (_db.select(
      _db.workoutTemplates,
    )..where((row) => row.routineId.isNull())).get();
    final duplicate = standaloneTemplates.any(
      (row) =>
          row.id != draft.id &&
          TrainingValidation.normalizeName(row.name) == normalizedName,
    );
    if (duplicate) {
      throw const DuplicateTrainingName(
        'name',
        'A Template with this name already exists',
      );
    }
  }

  Future<void> _replacePrescriptions(
    int templateId,
    List<ExercisePrescriptionDraft> prescriptions,
    DateTime timestamp,
  ) async {
    final existing = await (_db.select(
      _db.exercisePrescriptions,
    )..where((row) => row.templateId.equals(templateId))).get();
    final existingIds = existing.map((row) => row.id).toList();
    if (existingIds.isNotEmpty) {
      await (_db.delete(
        _db.plannedSets,
      )..where((row) => row.prescriptionId.isIn(existingIds))).go();
    }
    await (_db.delete(
      _db.exercisePrescriptions,
    )..where((row) => row.templateId.equals(templateId))).go();

    for (var position = 0; position < prescriptions.length; position++) {
      final prescription = prescriptions[position];
      final prescriptionId = await _db
          .into(_db.exercisePrescriptions)
          .insert(
            ExercisePrescriptionsCompanion.insert(
              templateId: templateId,
              exerciseId: prescription.exerciseId,
              position: position,
              notes: Value(prescription.notes),
              updatedAt: Value(timestamp),
            ),
          );
      for (
        var setPosition = 0;
        setPosition < prescription.plannedSets.length;
        setPosition++
      ) {
        final set = prescription.plannedSets[setPosition];
        await _db
            .into(_db.plannedSets)
            .insert(
              PlannedSetsCompanion.insert(
                prescriptionId: prescriptionId,
                position: setPosition,
                weight: Value(set.weight),
                minReps: Value(set.minReps),
                maxReps: Value(set.maxReps),
                rir: Value(set.rir),
                isDropset: Value(set.type == PlannedSetType.dropset),
              ),
            );
      }
    }
  }

  Future<List<ExercisePrescriptionDraft>> _loadPrescriptions(
    int templateId,
  ) async {
    final statement = _db.select(_db.exercisePrescriptions).join([
      innerJoin(
        _db.exercises,
        _db.exercises.id.equalsExp(_db.exercisePrescriptions.exerciseId),
      ),
    ]);
    statement
      ..where(_db.exercisePrescriptions.templateId.equals(templateId))
      ..orderBy([OrderingTerm.asc(_db.exercisePrescriptions.position)]);
    final rows = await statement.get();

    return Future.wait(
      rows.map((row) async {
        final prescription = row.readTable(_db.exercisePrescriptions);
        final exercise = row.readTable(_db.exercises);
        return ExercisePrescriptionDraft(
          id: prescription.id,
          exerciseId: prescription.exerciseId,
          exerciseName: exercise.name,
          notes: prescription.notes,
          plannedSets: await _loadPlannedSets(prescription.id),
        );
      }),
    );
  }

  Future<List<PlannedSetDraft>> _loadPlannedSets(int prescriptionId) async {
    final rows =
        await (_db.select(_db.plannedSets)
              ..where((row) => row.prescriptionId.equals(prescriptionId))
              ..orderBy([(row) => OrderingTerm.asc(row.position)]))
            .get();
    return [
      for (final row in rows)
        PlannedSetDraft(
          id: row.id,
          weight: row.weight,
          minReps: row.minReps,
          maxReps: row.maxReps,
          rir: row.rir,
          type: row.isDropset ? PlannedSetType.dropset : PlannedSetType.working,
        ),
    ];
  }

  @override
  Stream<List<RoutineSummary>> watchRoutines({
    required bool archived,
    String query = '',
  }) {
    throw UnimplementedError('Routine persistence is implemented in Task 4');
  }

  @override
  Future<RoutineDraft?> loadRoutine(int id) {
    throw UnimplementedError('Routine persistence is implemented in Task 4');
  }

  @override
  Future<int> saveRoutine(RoutineDraft draft) {
    throw UnimplementedError('Routine persistence is implemented in Task 4');
  }

  @override
  Future<int> saveRoutineTemplateAsStandalone(int templateId) {
    throw UnimplementedError('Routine persistence is implemented in Task 4');
  }

  @override
  Future<void> setRoutineArchived(int id, {required bool archived}) {
    throw UnimplementedError('Routine persistence is implemented in Task 4');
  }
}
