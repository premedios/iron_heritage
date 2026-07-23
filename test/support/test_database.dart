import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:iron_heritage/src/core/database/database.dart';

AppDatabase createTestDatabase() {
  return AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
}

AppDatabase createV2TestDatabase() {
  return AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(
        setup: (database) {
          database
            ..execute('''
              CREATE TABLE routines (
                id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                created_at INTEGER NOT NULL
              )
            ''')
            ..execute('''
              INSERT INTO routines (id, name, created_at)
              VALUES (7, 'Legacy routine', 1704067200)
            ''')
            ..execute('''
              CREATE TABLE workouts (
                id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                routine_id INTEGER REFERENCES routines (id),
                start_time INTEGER NOT NULL,
                end_time INTEGER
              )
            ''')
            ..execute('''
              CREATE TABLE exercises (
                id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                wger_id INTEGER UNIQUE,
                name TEXT NOT NULL,
                category TEXT,
                primary_muscles TEXT,
                secondary_muscles TEXT,
                equipment TEXT,
                mechanic TEXT,
                force TEXT,
                movement_pattern TEXT
              )
            ''')
            ..execute('''
              CREATE TABLE workout_sets (
                id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                workout_id INTEGER NOT NULL REFERENCES workouts (id),
                exercise_id INTEGER NOT NULL REFERENCES exercises (id),
                weight REAL,
                reps INTEGER NOT NULL,
                rir INTEGER,
                is_dropset INTEGER NOT NULL DEFAULT 0,
                is_skipped INTEGER NOT NULL DEFAULT 0
              )
            ''')
            ..execute('PRAGMA user_version = 2');
        },
      ),
      closeStreamsSynchronously: true,
    ),
  );
}
