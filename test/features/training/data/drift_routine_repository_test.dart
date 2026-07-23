import 'package:flutter_test/flutter_test.dart';
import 'package:iron_heritage/src/core/database/database.dart';
import 'package:iron_heritage/src/features/training/data/drift_training_repository.dart';
import 'package:iron_heritage/src/features/training/data/training_repository.dart';
import 'package:iron_heritage/src/features/training/domain/training_models.dart';

import '../../../support/test_database.dart';

void main() {
  late AppDatabase db;
  late DateTime currentTime;
  late DriftTrainingRepository repo;
  late WorkoutTemplateDraft chestTemplate;

  setUp(() async {
    db = createTestDatabase();
    currentTime = DateTime.utc(2026);
    repo = DriftTrainingRepository(db, now: () => currentTime);
    final exerciseId = await db
        .into(db.exercises)
        .insert(ExercisesCompanion.insert(name: 'Bench Press'));
    chestTemplate = WorkoutTemplateDraft(
      name: 'Chest',
      prescriptions: [
        ExercisePrescriptionDraft(
          exerciseId: exerciseId,
          exerciseName: 'Bench Press',
          notes: 'Pause',
          plannedSets: const [PlannedSetDraft(minReps: 8, maxReps: 12)],
        ),
      ],
    );
  });

  tearDown(() => db.close());

  test('Routine save deep-copies a standalone Template', () async {
    final standaloneId = await repo.saveTemplate(chestTemplate);
    final source = await repo.loadTemplate(standaloneId);

    final routineId = await repo.saveRoutine(
      RoutineDraft(name: 'PPL', templates: [source!.deepCopy()]),
    );
    final routine = await repo.loadRoutine(routineId);
    final owned = routine!.templates.single;

    expect(owned.id, isNot(standaloneId));
    expect(owned.routineId, routineId);
    expect(
      owned.prescriptions.single.id,
      isNot(source.prescriptions.single.id),
    );
    expect(
      owned.prescriptions.single.plannedSets.single.id,
      isNot(source.prescriptions.single.plannedSets.single.id),
    );

    await repo.saveTemplate(
      WorkoutTemplateDraft(
        id: owned.id,
        routineId: routineId,
        name: 'Chest Heavy',
        prescriptions: owned.prescriptions,
      ),
    );

    expect((await repo.loadTemplate(standaloneId))!.name, 'Chest');
  });

  test(
    'Save copy to Templates creates another independent aggregate',
    () async {
      final routineId = await repo.saveRoutine(
        RoutineDraft(name: 'PPL', templates: [chestTemplate]),
      );
      final owned = (await repo.loadRoutine(routineId))!.templates.single;

      final standaloneId = await repo.saveRoutineTemplateAsStandalone(
        owned.id!,
      );
      final standalone = await repo.loadTemplate(standaloneId);

      expect(standaloneId, isNot(owned.id));
      expect(standalone!.routineId, isNull);
      expect(
        standalone.prescriptions.single.id,
        isNot(owned.prescriptions.single.id),
      );
      expect(
        standalone.prescriptions.single.plannedSets.single.id,
        isNot(owned.prescriptions.single.plannedSets.single.id),
      );

      await repo.saveTemplate(
        WorkoutTemplateDraft(
          id: standaloneId,
          name: 'Chest Library',
          prescriptions: standalone.prescriptions,
        ),
      );
      expect((await repo.loadTemplate(owned.id!))!.name, 'Chest');
    },
  );

  test(
    'Routine names are unique case-insensitively among active rows',
    () async {
      final originalId = await repo.saveRoutine(
        RoutineDraft(name: ' Push Pull ', templates: [chestTemplate]),
      );

      await expectLater(
        repo.saveRoutine(
          RoutineDraft(name: 'pUsH pUlL', templates: [chestTemplate]),
        ),
        throwsA(
          isA<DuplicateTrainingName>()
              .having((error) => error.field, 'field', 'name')
              .having(
                (error) => error.message,
                'message',
                'A Routine with this name already exists',
              ),
        ),
      );

      await repo.setRoutineArchived(originalId, archived: true);
      final replacementId = await repo.saveRoutine(
        RoutineDraft(name: 'PUSH PULL', templates: [chestTemplate]),
      );

      await expectLater(
        repo.setRoutineArchived(originalId, archived: false),
        throwsA(isA<DuplicateTrainingName>()),
      );
      expect((await repo.loadRoutine(replacementId))!.name, 'PUSH PULL');
    },
  );

  test(
    'Template names are unique case-insensitively inside one Routine',
    () async {
      await expectLater(
        repo.saveRoutine(
          RoutineDraft(
            name: 'PPL',
            templates: [
              chestTemplate,
              WorkoutTemplateDraft(
                name: ' chest ',
                prescriptions: chestTemplate.prescriptions,
              ),
            ],
          ),
        ),
        throwsA(
          isA<InvalidTrainingDraft>().having(
            (error) => error.errors,
            'errors',
            containsPair(
              'templates.1.name',
              'Template names must be unique inside this Routine',
            ),
          ),
        ),
      );
    },
  );

  test(
    'removing an owned Template archives it instead of deleting it',
    () async {
      final legs = WorkoutTemplateDraft(
        name: 'Legs',
        prescriptions: chestTemplate.prescriptions,
      );
      final routineId = await repo.saveRoutine(
        RoutineDraft(name: 'PPL', templates: [chestTemplate, legs]),
      );
      final original = await repo.loadRoutine(routineId);
      final removedId = original!.templates.first.id!;
      final kept = original.templates.last;

      currentTime = DateTime.utc(2026, 1, 2);
      await repo.saveRoutine(
        RoutineDraft(id: routineId, name: 'PPL', templates: [kept]),
      );

      final loaded = await repo.loadRoutine(routineId);
      final removed = await (db.select(
        db.workoutTemplates,
      )..where((row) => row.id.equals(removedId))).getSingle();
      expect(loaded!.templates.single.id, kept.id);
      expect(
        removed.archivedAt?.millisecondsSinceEpoch,
        currentTime.millisecondsSinceEpoch,
      );
      expect((await repo.loadTemplate(removedId))!.name, 'Chest');
    },
  );

  test(
    'archiving a Routine hides it without changing standalone Templates',
    () async {
      final standaloneId = await repo.saveTemplate(chestTemplate);
      final routineId = await repo.saveRoutine(
        RoutineDraft(name: 'PPL', templates: [chestTemplate]),
      );
      final ownedId = (await repo.loadRoutine(routineId))!.templates.single.id!;

      await repo.setRoutineArchived(routineId, archived: true);

      expect(await repo.watchRoutines(archived: false).first, isEmpty);
      expect(
        (await repo.watchRoutines(archived: true).first).single.id,
        routineId,
      );
      expect((await repo.loadTemplate(standaloneId))!.archivedAt, isNull);
      expect((await repo.loadTemplate(ownedId))!.archivedAt, isNull);
    },
  );

  test(
    'watchRoutines searches Routine and ordered contained Template names',
    () async {
      final legs = WorkoutTemplateDraft(
        name: 'Leg Day',
        prescriptions: chestTemplate.prescriptions,
      );
      final pplId = await repo.saveRoutine(
        RoutineDraft(name: 'PPL', templates: [legs, chestTemplate]),
      );
      currentTime = DateTime.utc(2026, 1, 2);
      final upperId = await repo.saveRoutine(
        RoutineDraft(name: 'Upper', templates: [chestTemplate]),
      );

      expect(
        (await repo.watchRoutines(archived: false, query: 'LEG').first)
            .single
            .id,
        pplId,
      );
      expect(
        (await repo.watchRoutines(archived: false, query: 'upp').first)
            .single
            .id,
        upperId,
      );
      final summaries = await repo.watchRoutines(archived: false).first;
      expect(summaries.map((summary) => summary.id), [upperId, pplId]);
      expect(summaries.last.templateNames, ['Leg Day', 'Chest']);
    },
  );

  test('failed Routine aggregate save rolls back every inserted row', () async {
    final invalidTemplate = WorkoutTemplateDraft(
      name: 'Missing exercise',
      prescriptions: [
        ExercisePrescriptionDraft(
          exerciseId: 9999,
          exerciseName: 'Missing',
          plannedSets: const [PlannedSetDraft()],
        ),
      ],
    );

    await expectLater(
      repo.saveRoutine(
        RoutineDraft(name: 'Invalid', templates: [invalidTemplate]),
      ),
      throwsA(anything),
    );

    expect(await db.select(db.routines).get(), isEmpty);
    expect(await db.select(db.workoutTemplates).get(), isEmpty);
    expect(await db.select(db.exercisePrescriptions).get(), isEmpty);
    expect(await db.select(db.plannedSets).get(), isEmpty);
  });

  test('Save copy rejects standalone Templates and duplicate names', () async {
    final standaloneId = await repo.saveTemplate(chestTemplate);
    await expectLater(
      repo.saveRoutineTemplateAsStandalone(standaloneId),
      throwsA(isA<StateError>()),
    );

    final routineId = await repo.saveRoutine(
      RoutineDraft(name: 'PPL', templates: [chestTemplate]),
    );
    final ownedId = (await repo.loadRoutine(routineId))!.templates.single.id!;

    await expectLater(
      repo.saveRoutineTemplateAsStandalone(ownedId),
      throwsA(isA<DuplicateTrainingName>()),
    );
  });
}
