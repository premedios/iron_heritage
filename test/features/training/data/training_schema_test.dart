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
