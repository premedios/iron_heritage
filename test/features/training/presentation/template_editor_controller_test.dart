import 'package:flutter_test/flutter_test.dart';
import 'package:iron_heritage/src/features/training/data/training_repository.dart';
import 'package:iron_heritage/src/features/training/domain/training_models.dart';
import 'package:iron_heritage/src/features/training/presentation/template/template_editor_controller.dart';

import '../../../support/fake_training_repository.dart';

void main() {
  late FakeTrainingRepository fake;

  setUp(() {
    fake = FakeTrainingRepository();
  });

  tearDown(() => fake.dispose());

  group('adding Exercises', () {
    test('first-time Exercise receives one blank Planned Set', () async {
      final controller = TemplateEditorController(
        repository: fake,
        initial: WorkoutTemplateDraft(name: '', prescriptions: const []),
      );

      await controller.addExercises([
        const ExerciseChoice(id: 7, name: 'Bench Press'),
      ]);

      final prescription = controller.draft.prescriptions.single;
      expect(prescription.exerciseId, 7);
      expect(prescription.exerciseName, 'Bench Press');
      expect(prescription.plannedSets, hasLength(1));
      expect(prescription.plannedSets.single.id, isNull);
      expect(prescription.plannedSets.single.type, PlannedSetType.working);
      expect(controller.dirty, isTrue);
    });

    test(
      'used Exercises receive independent deep copies in selection order',
      () async {
        fake.latestByExercise[7] = ExercisePrescriptionDraft(
          id: 31,
          exerciseId: 7,
          exerciseName: 'Bench Press',
          notes: 'Pause',
          plannedSets: const [PlannedSetDraft(id: 41, minReps: 8, maxReps: 12)],
        );
        fake.latestByExercise[9] = ExercisePrescriptionDraft(
          id: 32,
          exerciseId: 9,
          exerciseName: 'Cable Fly',
          plannedSets: const [PlannedSetDraft(id: 42, minReps: 12)],
        );
        final controller = TemplateEditorController(
          repository: fake,
          initial: WorkoutTemplateDraft(name: '', prescriptions: const []),
        );

        await controller.addExercises([
          const ExerciseChoice(id: 9, name: 'Cable Fly'),
          const ExerciseChoice(id: 7, name: 'Bench Press'),
        ]);

        expect(
          controller.draft.prescriptions.map(
            (prescription) => prescription.exerciseId,
          ),
          [9, 7],
        );
        final bench = controller.draft.prescriptions.last;
        expect(bench.notes, 'Pause');
        expect(bench.id, isNull);
        expect(bench.plannedSets.single.id, isNull);
        expect(
          bench.plannedSets.single,
          isNot(same(fake.latestByExercise[7]!.plannedSets.single)),
        );
      },
    );
  });

  group('mutations', () {
    test('preserve persisted aggregate and child identities', () {
      final archivedAt = DateTime.utc(2026, 7, 1);
      final controller = TemplateEditorController(
        repository: fake,
        initial: WorkoutTemplateDraft(
          id: 11,
          routineId: 12,
          archivedAt: archivedAt,
          name: 'Chest',
          prescriptions: [
            ExercisePrescriptionDraft(
              id: 21,
              exerciseId: 7,
              exerciseName: 'Bench Press',
              notes: 'Old',
              plannedSets: const [PlannedSetDraft(id: 31, minReps: 8)],
            ),
          ],
        ),
      );

      controller
        ..setName('Upper')
        ..setNotes(0, 'Pause')
        ..updatePlannedSet(0, 0, const PlannedSetDraft(id: 31, minReps: 10))
        ..addPlannedSet(0);

      expect(controller.draft.id, 11);
      expect(controller.draft.routineId, 12);
      expect(controller.draft.archivedAt, archivedAt);
      expect(controller.draft.prescriptions.single.id, 21);
      expect(controller.draft.prescriptions.single.plannedSets.first.id, 31);
      expect(controller.draft.prescriptions.single.plannedSets.last.id, isNull);
      expect(controller.dirty, isTrue);
    });

    test('remove and reorder operations update ordered immutable lists', () {
      final controller = TemplateEditorController(
        repository: fake,
        initial: WorkoutTemplateDraft(
          name: 'Upper',
          prescriptions: [
            ExercisePrescriptionDraft(
              exerciseId: 7,
              exerciseName: 'Bench',
              plannedSets: const [
                PlannedSetDraft(minReps: 5),
                PlannedSetDraft(minReps: 8),
                PlannedSetDraft(minReps: 12),
              ],
            ),
            ExercisePrescriptionDraft(
              exerciseId: 9,
              exerciseName: 'Fly',
              plannedSets: const [PlannedSetDraft()],
            ),
            ExercisePrescriptionDraft(
              exerciseId: 10,
              exerciseName: 'Dip',
              plannedSets: const [PlannedSetDraft()],
            ),
          ],
        ),
      );

      controller
        ..reorderPlannedSets(0, 0, 3)
        ..removePlannedSet(0, 1)
        ..reorderExercises(0, 3)
        ..removeExercise(1);

      expect(
        controller.draft.prescriptions.last.plannedSets.map(
          (set) => set.minReps,
        ),
        [8, 5],
      );
      expect(
        controller.draft.prescriptions.map(
          (prescription) => prescription.exerciseName,
        ),
        ['Fly', 'Bench'],
      );
      expect(
        () => controller.draft.prescriptions.add(
          ExercisePrescriptionDraft(
            exerciseId: 99,
            exerciseName: 'Mutable',
            plannedSets: const [PlannedSetDraft()],
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('mutation clears stale errors and notifies listeners', () {
      final controller = TemplateEditorController(
        repository: fake,
        initial: WorkoutTemplateDraft(name: '', prescriptions: const []),
      );
      expect(controller.completeDraft(), isNull);
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.setName('Chest');

      expect(controller.errors, isEmpty);
      expect(
        () => controller.errors['name'] = 'changed',
        throwsUnsupportedError,
      );
      expect(notifications, 1);
    });
  });

  group('completion modes', () {
    test('embedded completion validates without persistence', () {
      final controller = TemplateEditorController(
        repository: fake,
        initial: _validTemplate(routineId: 12),
      );
      controller.setNotes(0, 'Routine-only');

      final completed = controller.completeDraft();

      expect(completed, same(controller.draft));
      expect(completed!.routineId, 12);
      expect(fake.savedTemplates, isEmpty);
      expect(controller.dirty, isTrue);
      expect(controller.errors, isEmpty);
    });

    test('invalid embedded completion exposes field errors', () {
      final controller = TemplateEditorController(
        repository: fake,
        initial: WorkoutTemplateDraft(name: ' ', prescriptions: const []),
      );

      expect(controller.completeDraft(), isNull);
      expect(controller.errors, {
        'name': 'Enter a Template name',
        'prescriptions': 'Add at least one exercise',
      });
      expect(controller.dirty, isTrue);
    });

    test(
      'persisted save returns ID and becomes clean only on success',
      () async {
        final controller = TemplateEditorController(
          repository: fake,
          initial: _validTemplate(id: 17),
        );
        final savingStates = <bool>[];
        controller.addListener(() => savingStates.add(controller.saving));
        controller.setName('Upper');
        savingStates.clear();

        expect(await controller.save(), 17);

        expect(fake.savedTemplates.single, same(controller.draft));
        expect(controller.dirty, isFalse);
        expect(controller.saving, isFalse);
        expect(savingStates, [true, false]);
      },
    );

    test('failed save retains draft and maps duplicate-name error', () async {
      fake.saveError = const DuplicateTrainingName(
        'name',
        'A Template with this name already exists',
      );
      final initial = _validTemplate();
      final controller = TemplateEditorController(
        repository: fake,
        initial: initial,
      );

      expect(await controller.save(), isNull);
      expect(controller.draft, same(initial));
      expect(controller.dirty, isTrue);
      expect(controller.saving, isFalse);
      expect(controller.errors['name'], contains('already exists'));
    });

    test(
      'repository validation errors are exposed without losing draft',
      () async {
        fake.saveError = const InvalidTrainingDraft({
          'prescriptions.0.plannedSets': 'Rejected by storage',
        });
        final initial = _validTemplate();
        final controller = TemplateEditorController(
          repository: fake,
          initial: initial,
        );

        expect(await controller.save(), isNull);
        expect(controller.draft, same(initial));
        expect(controller.errors, {
          'prescriptions.0.plannedSets': 'Rejected by storage',
        });
        expect(controller.dirty, isTrue);
      },
    );

    test('local validation prevents persistence', () async {
      final controller = TemplateEditorController(
        repository: fake,
        initial: WorkoutTemplateDraft(name: '', prescriptions: const []),
      );

      expect(await controller.save(), isNull);
      expect(fake.savedTemplates, isEmpty);
      expect(controller.errors['name'], isNotEmpty);
      expect(controller.dirty, isTrue);
      expect(controller.saving, isFalse);
    });
  });
}

WorkoutTemplateDraft _validTemplate({int? id, int? routineId}) {
  return WorkoutTemplateDraft(
    id: id,
    routineId: routineId,
    name: 'Chest',
    prescriptions: [
      ExercisePrescriptionDraft(
        exerciseId: 7,
        exerciseName: 'Bench Press',
        notes: 'Pause',
        plannedSets: const [PlannedSetDraft(minReps: 8, maxReps: 12)],
      ),
    ],
  );
}
