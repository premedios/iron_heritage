import 'package:flutter_test/flutter_test.dart';
import 'package:iron_heritage/src/features/training/domain/training_models.dart';
import 'package:iron_heritage/src/features/training/domain/training_validation.dart';

void main() {
  const blankSet = PlannedSetDraft();
  const bench = ExercisePrescriptionDraft(
    exerciseId: 7,
    exerciseName: 'Bench Press',
    plannedSets: [blankSet],
  );

  test('blank Planned Set targets form a valid Template', () {
    const draft = WorkoutTemplateDraft(name: 'Chest', prescriptions: [bench]);
    expect(TrainingValidation.template(draft), isEmpty);
  });

  test('Template requires one Planned Set per Exercise', () {
    const draft = WorkoutTemplateDraft(
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
    const source = WorkoutTemplateDraft(
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
}
