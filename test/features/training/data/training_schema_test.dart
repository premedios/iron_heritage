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
}
