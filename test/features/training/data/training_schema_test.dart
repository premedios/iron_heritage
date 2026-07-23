import 'package:flutter_test/flutter_test.dart';
import 'package:iron_heritage/src/core/database/database.dart';

import '../../../support/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  test('schema v3 creates every Training table', () async {
    expect(db.schemaVersion, 3);
    expect(await db.select(db.routines).get(), isEmpty);
    expect(await db.select(db.workoutTemplates).get(), isEmpty);
    expect(await db.select(db.exercisePrescriptions).get(), isEmpty);
    expect(await db.select(db.plannedSets).get(), isEmpty);
  });

  test(
    'v1 upgrade adds absent legacy columns and preserves populated rows',
    () async {
      await db.close();
      db = createV1TestDatabase(addedColumnsPresent: false);

      final exercise = await db.select(db.exercises).getSingle();
      final set = await db.select(db.workoutSets).getSingle();

      expect(exercise.id, 17);
      expect(exercise.name, 'Bench Press');
      expect(exercise.mechanic, isNull);
      expect(exercise.force, isNull);
      expect(exercise.movementPattern, isNull);
      expect(set.id, 19);
      expect(set.isSkipped, isFalse);
      expect((await db.select(db.routines).getSingle()).updatedAt, isNotNull);
      expect(await db.select(db.workoutTemplates).get(), isEmpty);
    },
  );

  test(
    'v1 upgrade tolerates already-added columns and preserves their data',
    () async {
      await db.close();
      db = createV1TestDatabase(addedColumnsPresent: true);

      final exercise = await db.select(db.exercises).getSingle();
      final set = await db.select(db.workoutSets).getSingle();

      expect(exercise.id, 17);
      expect(exercise.mechanic, 'Compound');
      expect(exercise.force, 'Push');
      expect(exercise.movementPattern, 'Horizontal');
      expect(set.id, 19);
      expect(set.isSkipped, isTrue);
      expect((await db.select(db.routines).getSingle()).updatedAt, isNotNull);
      expect(await db.select(db.workoutTemplates).get(), isEmpty);
    },
  );

  test(
    'v2 upgrade preserves populated routines and creates Training tables',
    () async {
      await db.close();
      db = createV2TestDatabase();

      final routine = await db.select(db.routines).getSingle();

      expect(routine.id, 7);
      expect(routine.name, 'Legacy routine');
      expect(
        routine.createdAt,
        DateTime.fromMillisecondsSinceEpoch(1704067200000),
      );
      expect(
        routine.updatedAt,
        DateTime.fromMillisecondsSinceEpoch(1704067200000),
      );
      expect(routine.archivedAt, isNull);
      expect(await db.select(db.workoutTemplates).get(), isEmpty);
      expect(await db.select(db.exercisePrescriptions).get(), isEmpty);
      expect(await db.select(db.plannedSets).get(), isEmpty);
    },
  );
}
