import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Routines,
    WorkoutTemplates,
    ExercisePrescriptions,
    PlannedSets,
    Workouts,
    Exercises,
    WorkoutSets,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(exercises, exercises.mechanic);
        await m.addColumn(exercises, exercises.force);
        await m.addColumn(exercises, exercises.movementPattern);
        await m.addColumn(workoutSets, workoutSets.isSkipped);
        await delete(workoutSets).go();
        await delete(exercises).go();
      }
      if (from < 3) {
        await customStatement('''
          CREATE TABLE routines_new (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
            updated_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
            archived_at INTEGER
          )
        ''');
        await customStatement('''
          INSERT INTO routines_new (id, name, created_at, updated_at, archived_at)
          SELECT id, name, created_at, created_at, NULL FROM routines
        ''');
        await customStatement('DROP TABLE routines');
        await customStatement('ALTER TABLE routines_new RENAME TO routines');
        await m.createTable(workoutTemplates);
        await m.createTable(exercisePrescriptions);
        await m.createTable(plannedSets);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'iron_heritage_db');
  }
}
