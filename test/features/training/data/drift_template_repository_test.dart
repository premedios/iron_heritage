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

  setUp(() {
    db = createTestDatabase();
    currentTime = DateTime.utc(2026);
    repo = DriftTrainingRepository(db, now: () => currentTime);
  });

  tearDown(() => db.close());

  Future<int> addExercise(String name) {
    return db.into(db.exercises).insert(ExercisesCompanion.insert(name: name));
  }

  WorkoutTemplateDraft template({
    int? id,
    required String name,
    required int exerciseId,
    String exerciseName = 'Bench Press',
    String? notes,
    List<PlannedSetDraft> sets = const [PlannedSetDraft()],
  }) {
    return WorkoutTemplateDraft(
      id: id,
      name: name,
      prescriptions: [
        ExercisePrescriptionDraft(
          exerciseId: exerciseId,
          exerciseName: exerciseName,
          notes: notes,
          plannedSets: sets,
        ),
      ],
    );
  }

  test('saves, watches, searches, and archives standalone Templates', () async {
    final exerciseId = await addExercise('Bench Press');
    final stream = repo.watchTemplates(archived: false, query: 'bench');

    final id = await repo.saveTemplate(
      template(name: 'Chest', exerciseId: exerciseId),
    );

    expect((await stream.first).single.id, id);
    expect(
      (await repo.watchTemplates(archived: false, query: 'CHE').first)
          .single
          .id,
      id,
    );

    await repo.setTemplateArchived(id, archived: true);

    expect(await repo.watchTemplates(archived: false).first, isEmpty);
    expect((await repo.watchTemplates(archived: true).first).single.id, id);
  });

  test(
    'loads persisted prescriptions and Planned Sets in list order',
    () async {
      final benchId = await addExercise('Bench Press');
      final flyId = await addExercise('Cable Fly');
      final id = await repo.saveTemplate(
        WorkoutTemplateDraft(
          name: ' Chest ',
          prescriptions: [
            ExercisePrescriptionDraft(
              exerciseId: flyId,
              exerciseName: 'ignored draft name',
              notes: 'Slow eccentric',
              plannedSets: const [
                PlannedSetDraft(
                  weight: 12.5,
                  minReps: 10,
                  maxReps: 15,
                  rir: 2,
                  type: PlannedSetType.dropset,
                ),
                PlannedSetDraft(minReps: 15),
              ],
            ),
            ExercisePrescriptionDraft(
              exerciseId: benchId,
              exerciseName: 'also ignored',
              plannedSets: const [PlannedSetDraft(minReps: 8, maxReps: 12)],
            ),
          ],
        ),
      );

      final loaded = await repo.loadTemplate(id);

      expect(loaded?.name, 'Chest');
      expect(loaded?.prescriptions.map((item) => item.exerciseName), [
        'Cable Fly',
        'Bench Press',
      ]);
      expect(loaded?.prescriptions.first.notes, 'Slow eccentric');
      expect(loaded?.prescriptions.first.plannedSets, hasLength(2));
      expect(loaded?.prescriptions.first.plannedSets.first.weight, 12.5);
      expect(
        loaded?.prescriptions.first.plannedSets.first.type,
        PlannedSetType.dropset,
      );
      expect(loaded?.prescriptions.first.id, isNotNull);
      expect(loaded?.prescriptions.first.plannedSets.first.id, isNotNull);
    },
  );

  test('latest prescription is copied, not aliased', () async {
    final exerciseId = await addExercise('Bench Press');
    await repo.saveTemplate(
      template(
        name: 'Chest',
        exerciseId: exerciseId,
        notes: 'Pause',
        sets: const [PlannedSetDraft(minReps: 8, maxReps: 12)],
      ),
    );

    final latest = await repo.latestPrescription(exerciseId);

    expect(latest?.id, isNull);
    expect(latest?.notes, 'Pause');
    expect(latest?.plannedSets.single.id, isNull);
  });

  test(
    'rejects case-insensitive standalone names across active and archived rows',
    () async {
      final exerciseId = await addExercise('Bench Press');
      final id = await repo.saveTemplate(
        template(name: ' Chest ', exerciseId: exerciseId),
      );
      await repo.setTemplateArchived(id, archived: true);

      await expectLater(
        repo.saveTemplate(template(name: 'cHeSt', exerciseId: exerciseId)),
        throwsA(
          isA<DuplicateTrainingName>()
              .having((error) => error.field, 'field', 'name')
              .having(
                (error) => error.message,
                'message',
                'A Template with this name already exists',
              ),
        ),
      );
    },
  );

  test('sorts standalone Template summaries by updatedAt descending', () async {
    final exerciseId = await addExercise('Bench Press');
    final olderId = await repo.saveTemplate(
      template(name: 'Older', exerciseId: exerciseId),
    );
    currentTime = DateTime.utc(2026, 1, 2);
    final newerId = await repo.saveTemplate(
      template(name: 'Newer', exerciseId: exerciseId),
    );

    final summaries = await repo.watchTemplates(archived: false).first;

    expect(summaries.map((item) => item.id), [newerId, olderId]);
    expect(summaries.map((item) => item.updatedAt.millisecondsSinceEpoch), [
      DateTime.utc(2026, 1, 2).millisecondsSinceEpoch,
      DateTime.utc(2026).millisecondsSinceEpoch,
    ]);
  });

  test('updates standalone Templates and replaces their aggregate', () async {
    final benchId = await addExercise('Bench Press');
    final flyId = await addExercise('Cable Fly');
    final id = await repo.saveTemplate(
      template(name: 'Chest', exerciseId: benchId),
    );
    currentTime = DateTime.utc(2026, 1, 2);

    final returnedId = await repo.saveTemplate(
      template(
        id: id,
        name: 'Chest and Fly',
        exerciseId: flyId,
        exerciseName: 'Cable Fly',
        notes: 'Stretch',
        sets: const [PlannedSetDraft(maxReps: 15)],
      ),
    );

    final loaded = await repo.loadTemplate(id);
    expect(returnedId, id);
    expect(loaded?.name, 'Chest and Fly');
    expect(loaded?.prescriptions.single.exerciseName, 'Cable Fly');
    expect(loaded?.prescriptions.single.notes, 'Stretch');
    expect(await db.select(db.exercisePrescriptions).get(), hasLength(1));
    expect(await db.select(db.plannedSets).get(), hasLength(1));
  });

  test('rejects structurally invalid Template drafts', () async {
    await expectLater(
      repo.saveTemplate(WorkoutTemplateDraft(name: ' ', prescriptions: [])),
      throwsA(
        isA<InvalidTrainingDraft>().having((error) => error.errors, 'errors', {
          'name': 'Enter a Template name',
          'prescriptions': 'Add at least one exercise',
        }),
      ),
    );
  });
}
