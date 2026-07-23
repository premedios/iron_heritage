import 'package:flutter_test/flutter_test.dart';
import 'package:iron_heritage/src/features/training/domain/training_models.dart';
import 'package:iron_heritage/src/features/training/domain/training_validation.dart';

void main() {
  const blankSet = PlannedSetDraft();
  final bench = ExercisePrescriptionDraft(
    exerciseId: 7,
    exerciseName: 'Bench Press',
    plannedSets: [blankSet],
  );

  test('blank Planned Set targets form a valid Template', () {
    final draft = WorkoutTemplateDraft(name: 'Chest', prescriptions: [bench]);
    expect(TrainingValidation.template(draft), isEmpty);
  });

  test('Template requires one Planned Set per Exercise', () {
    final draft = WorkoutTemplateDraft(
      name: 'Chest',
      prescriptions: [
        ExercisePrescriptionDraft(
          exerciseId: 7,
          exerciseName: 'Bench Press',
          plannedSets: [],
        ),
      ],
    );
    expect(
      TrainingValidation.template(draft),
      containsPair('prescriptions.0.plannedSets', 'Add at least one set'),
    );
  });

  test('deep copy clears identities and never aliases child lists', () {
    final source = WorkoutTemplateDraft(
      id: 12,
      name: 'Chest',
      prescriptions: [
        ExercisePrescriptionDraft(
          id: 13,
          exerciseId: 7,
          exerciseName: 'Bench Press',
          notes: 'Pause',
          plannedSets: [PlannedSetDraft(id: 14, minReps: 8, maxReps: 12)],
        ),
      ],
    );

    final copy = source.deepCopy(routineId: 4);

    expect(copy.id, isNull);
    expect(copy.routineId, 4);
    expect(copy.prescriptions.single.id, isNull);
    expect(copy.prescriptions.single.plannedSets.single.id, isNull);
    expect(copy.prescriptions.single.notes, 'Pause');
    expect(identical(source.prescriptions, copy.prescriptions), isFalse);
  });

  test('Exercise Prescription snapshots and protects Planned Sets', () {
    final callerSets = <PlannedSetDraft>[blankSet];
    final draft = ExercisePrescriptionDraft(
      exerciseId: 7,
      exerciseName: 'Bench Press',
      plannedSets: callerSets,
    );

    callerSets.add(const PlannedSetDraft(minReps: 8));

    expect(draft.plannedSets, [blankSet]);
    expect(
      () => draft.plannedSets.add(const PlannedSetDraft()),
      throwsUnsupportedError,
    );
  });

  test('Workout Template snapshots and protects Prescriptions', () {
    final callerPrescriptions = <ExercisePrescriptionDraft>[bench];
    final draft = WorkoutTemplateDraft(
      name: 'Chest',
      prescriptions: callerPrescriptions,
    );

    callerPrescriptions.clear();

    expect(draft.prescriptions, [bench]);
    expect(() => draft.prescriptions.clear(), throwsUnsupportedError);
  });

  test('Routine snapshots and protects Templates', () {
    final template = WorkoutTemplateDraft(
      name: 'Chest',
      prescriptions: [bench],
    );
    final callerTemplates = <WorkoutTemplateDraft>[template];
    final draft = RoutineDraft(name: 'Push', templates: callerTemplates);

    callerTemplates.clear();

    expect(draft.templates, [template]);
    expect(() => draft.templates.clear(), throwsUnsupportedError);
  });

  test('Workout Template Summary snapshots and protects exercise names', () {
    final callerNames = <String>['Bench Press'];
    final summary = WorkoutTemplateSummary(
      id: 1,
      name: 'Chest',
      exerciseNames: callerNames,
      updatedAt: DateTime.utc(2026),
    );

    callerNames.add('Incline Press');

    expect(summary.exerciseNames, ['Bench Press']);
    expect(() => summary.exerciseNames.add('Fly'), throwsUnsupportedError);
  });

  test('Routine Summary snapshots and protects Template names', () {
    final callerNames = <String>['Chest'];
    final summary = RoutineSummary(
      id: 1,
      name: 'Push',
      templateNames: callerNames,
      updatedAt: DateTime.utc(2026),
    );

    callerNames.add('Shoulders');

    expect(summary.templateNames, ['Chest']);
    expect(() => summary.templateNames.add('Arms'), throwsUnsupportedError);
  });

  test('deep copies expose protected child lists', () {
    final prescription = ExercisePrescriptionDraft(
      id: 13,
      exerciseId: 7,
      exerciseName: 'Bench Press',
      plannedSets: const [PlannedSetDraft(id: 14)],
    );
    final template = WorkoutTemplateDraft(
      id: 12,
      name: 'Chest',
      prescriptions: [prescription],
    );

    final prescriptionCopy = prescription.deepCopy();
    final templateCopy = template.deepCopy();

    expect(
      () => prescriptionCopy.plannedSets.add(const PlannedSetDraft()),
      throwsUnsupportedError,
    );
    expect(
      () => templateCopy.prescriptions.add(prescription),
      throwsUnsupportedError,
    );
    expect(
      () => templateCopy.prescriptions.single.plannedSets.add(
        const PlannedSetDraft(),
      ),
      throwsUnsupportedError,
    );
  });
}
