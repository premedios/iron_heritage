# Training Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the local-first Training destination with standalone Workout Templates, independent Routine-owned Template copies, creation/edit/detail/archive flows, search, and accessible ordering.

**Architecture:** Add normalized Drift tables for Templates, Exercise Prescriptions, and Planned Sets. Keep business rules in immutable domain drafts and a feature-local repository, expose repository streams through Riverpod, and build focused Material screens that receive navigation callbacks. A three-destination `AppShell` owns bottom navigation and preserves destination state with an `IndexedStack`.

**Tech Stack:** Flutter 3.44, Dart 3.12, Material, Riverpod 3.3, Drift 2.34, flutter_test

## Global Constraints

- Android and iOS only.
- Keep `sdk: ^3.12.2`.
- Every run/build requires `--flavor dev` or `--flavor prod`; tests do not accept a flavor.
- Local-first: Training reads and writes Drift only.
- Calendar exclusively owns scheduling, cancellation, and rescheduling.
- No Active Routine or implicit next-Template state.
- Routine-owned Templates are independent deep copies per `docs/adr/0004-workout-template-copy-semantics.md`.
- A Template requires a unique scoped name, at least one Exercise Prescription, and at least one Planned Set per Exercise; Planned Set targets may all be blank.
- Generated `.g.dart` files are committed.
- Do not add dependencies.
- Run `dart run build_runner build` after Drift or Riverpod generator inputs change.
- Preserve the existing v1→v2 Exercise migration while advancing the database to schema version 3.

## Execution Precondition

Create an isolated worktree from a branch containing commit `6615245`. The main worktree currently has an uncommitted v1→v2 migration in `lib/src/core/database/database.dart`; Task 1 intentionally incorporates the same migration into the v3 migration. Do not copy, reset, or overwrite the main worktree.

## File Structure

### Core database and navigation

- Modify `lib/src/core/database/tables.dart`: normalized Training tables and Routine archive/update columns.
- Modify `lib/src/core/database/database.dart`: injectable executor, schema v3 migration, foreign-key enforcement.
- Regenerate `lib/src/core/database/database.g.dart`.
- Create `lib/src/core/navigation/app_shell.dart`: state-preserving Home/Training/Calendar bottom navigation.
- Modify `lib/app.dart`: show `AppShell` after Wger sync.
- Delete `lib/src/features/dashboard/presentation/dashboard_screen.dart`: replace the temporary dashboard.

### Training domain and data

- Create `lib/src/features/training/domain/training_models.dart`: drafts, summaries, detail values, Planned Set type.
- Create `lib/src/features/training/domain/training_validation.dart`: normalization and structural validation.
- Create `lib/src/features/training/data/training_repository.dart`: repository contract and typed failures.
- Create `lib/src/features/training/data/drift_training_repository.dart`: atomic Drift implementation.
- Create `lib/src/features/training/presentation/training_providers.dart`: Riverpod repository and list streams.
- Create `lib/src/features/training/presentation/training_destination.dart`: feature route coordinator.

### Training presentation

- Create `lib/src/features/training/presentation/training_screen.dart`: app bar, tabs, search, selected-tab actions.
- Create `lib/src/features/training/presentation/archived_training_screen.dart`: archive lists and restore actions.
- Create `lib/src/features/training/presentation/widgets/training_list_cards.dart`: Template and Routine summaries.
- Create `lib/src/features/training/presentation/widgets/training_list_state.dart`: skeleton, empty, no-result, error states.
- Create `lib/src/features/training/presentation/widgets/accessible_reorder_handle.dart`: drag plus semantic move actions.
- Create `lib/src/features/training/presentation/template/template_editor_controller.dart`: draft mutations and save orchestration.
- Create `lib/src/features/training/presentation/template/template_editor_screen.dart`: Template form and inline prescriptions.
- Create `lib/src/features/training/presentation/template/exercise_picker_screen.dart`: searchable, filterable multi-select catalog.
- Create `lib/src/features/training/presentation/template/template_detail_screen.dart`: read-first detail, start, edit, archive.
- Create `lib/src/features/training/presentation/routine/routine_editor_controller.dart`: Routine draft and copy orchestration.
- Create `lib/src/features/training/presentation/routine/routine_editor_screen.dart`: Routine form and ordering.
- Create `lib/src/features/training/presentation/routine/template_picker_sheet.dart`: multi-select existing or create new.
- Create `lib/src/features/training/presentation/routine/routine_detail_screen.dart`: read-first detail and owned-Template navigation.

### Test support and coverage

- Create `test/support/test_database.dart`: in-memory Drift factory.
- Create `test/support/fake_training_repository.dart`: deterministic UI fake.
- Create focused tests under `test/features/training/`.
- Modify `test/widget_test.dart`: app-shell integration.

---

### Task 1: Training Database Schema

**Files:**
- Modify: `lib/src/core/database/tables.dart`
- Modify: `lib/src/core/database/database.dart`
- Regenerate: `lib/src/core/database/database.g.dart`
- Create: `test/support/test_database.dart`
- Create: `test/features/training/data/training_schema_test.dart`

**Interfaces:**
- Produces: `AppDatabase([QueryExecutor? executor])`
- Produces tables: `routines`, `workoutTemplates`, `exercisePrescriptions`, `plannedSets`
- Preserves existing tables: `workouts`, `exercises`, `workoutSets`

- [ ] **Step 1: Write the failing schema test**

```dart
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
```

`test/support/test_database.dart`:

```dart
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/training/data/training_schema_test.dart`

Expected: FAIL because `AppDatabase` does not accept a `QueryExecutor` and the Training tables do not exist.

- [ ] **Step 3: Add the normalized tables**

Add these declarations to `tables.dart`; retain `Exercises`, `Workouts`, `WorkoutSets`, and `ListConverter` unchanged:

```dart
@DataClassName('RoutineRow')
class Routines extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get archivedAt => dateTime().nullable()();
}

@DataClassName('WorkoutTemplateRow')
class WorkoutTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get routineId => integer().nullable().references(Routines, #id)();
  TextColumn get name => text()();
  IntColumn get position => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get archivedAt => dateTime().nullable()();
}

@DataClassName('ExercisePrescriptionRow')
class ExercisePrescriptions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get templateId => integer().references(WorkoutTemplates, #id)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get position => integer()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('PlannedSetRow')
class PlannedSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get prescriptionId =>
      integer().references(ExercisePrescriptions, #id)();
  IntColumn get position => integer()();
  RealColumn get weight => real().nullable()();
  IntColumn get minReps => integer().nullable()();
  IntColumn get maxReps => integer().nullable()();
  IntColumn get rir => integer().nullable()();
  BoolColumn get isDropset =>
      boolean().withDefault(const Constant(false))();
}
```

- [ ] **Step 4: Add the v3 database constructor and migration**

Use this database shape:

```dart
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
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

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
            await m.addColumn(routines, routines.updatedAt);
            await m.addColumn(routines, routines.archivedAt);
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
```

- [ ] **Step 5: Regenerate Drift code**

Run: `dart run build_runner build`

Expected: `database.g.dart` includes the four Training row types and table getters.

- [ ] **Step 6: Run schema tests**

Run: `flutter test test/features/training/data/training_schema_test.dart`

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/src/core/database/tables.dart lib/src/core/database/database.dart lib/src/core/database/database.g.dart test/support/test_database.dart test/features/training/data/training_schema_test.dart
git commit -m "feat(training): add Training persistence schema"
```

### Task 2: Domain Drafts, Validation, and Deep Copy

**Files:**
- Create: `lib/src/features/training/domain/training_models.dart`
- Create: `lib/src/features/training/domain/training_validation.dart`
- Create: `test/features/training/domain/training_validation_test.dart`

**Interfaces:**
- Produces: `PlannedSetDraft`, `ExercisePrescriptionDraft`, `WorkoutTemplateDraft`, `RoutineDraft`
- Produces: `WorkoutTemplateSummary`, `RoutineSummary`
- Produces: `TrainingValidation.template`, `TrainingValidation.routine`
- Produces: `WorkoutTemplateDraft.deepCopy({int? routineId})`

- [ ] **Step 1: Write failing domain tests**

```dart
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
    const draft = WorkoutTemplateDraft(
      name: 'Chest',
      prescriptions: [bench],
    );
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
    expect(
      identical(source.prescriptions, copy.prescriptions),
      isFalse,
    );
  });
}
```

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/features/training/domain/training_validation_test.dart`

Expected: FAIL because the domain types do not exist.

- [ ] **Step 3: Implement immutable domain values**

Use const constructors and unmodifiable lists. The public shape must be:

```dart
enum PlannedSetType { working, dropset }

final class PlannedSetDraft {
  const PlannedSetDraft({
    this.id,
    this.weight,
    this.minReps,
    this.maxReps,
    this.rir,
    this.type = PlannedSetType.working,
  });

  final int? id;
  final double? weight;
  final int? minReps;
  final int? maxReps;
  final int? rir;
  final PlannedSetType type;

  PlannedSetDraft deepCopy() => PlannedSetDraft(
        weight: weight,
        minReps: minReps,
        maxReps: maxReps,
        rir: rir,
        type: type,
      );
}

final class ExercisePrescriptionDraft {
  const ExercisePrescriptionDraft({
    this.id,
    required this.exerciseId,
    required this.exerciseName,
    this.notes,
    required this.plannedSets,
  });

  final int? id;
  final int exerciseId;
  final String exerciseName;
  final String? notes;
  final List<PlannedSetDraft> plannedSets;

  ExercisePrescriptionDraft deepCopy() => ExercisePrescriptionDraft(
        exerciseId: exerciseId,
        exerciseName: exerciseName,
        notes: notes,
        plannedSets: plannedSets.map((set) => set.deepCopy()).toList(),
      );
}

final class WorkoutTemplateDraft {
  const WorkoutTemplateDraft({
    this.id,
    this.routineId,
    this.archivedAt,
    required this.name,
    required this.prescriptions,
  });

  final int? id;
  final int? routineId;
  final DateTime? archivedAt;
  final String name;
  final List<ExercisePrescriptionDraft> prescriptions;

  WorkoutTemplateDraft deepCopy({int? routineId}) => WorkoutTemplateDraft(
        routineId: routineId,
        name: name,
        prescriptions:
            prescriptions.map((item) => item.deepCopy()).toList(),
      );
}

final class RoutineDraft {
  const RoutineDraft({
    this.id,
    this.archivedAt,
    required this.name,
    required this.templates,
  });

  final int? id;
  final DateTime? archivedAt;
  final String name;
  final List<WorkoutTemplateDraft> templates;
}

final class ExerciseChoice {
  const ExerciseChoice({required this.id, required this.name});
  final int id;
  final String name;
}

final class WorkoutTemplateSummary {
  const WorkoutTemplateSummary({
    required this.id,
    required this.name,
    required this.exerciseNames,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final List<String> exerciseNames;
  final DateTime updatedAt;
}

final class RoutineSummary {
  const RoutineSummary({
    required this.id,
    required this.name,
    required this.templateNames,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final List<String> templateNames;
  final DateTime updatedAt;
}
```

Controller mutations rebuild values with new list instances; no mutable child list is shared across drafts.

- [ ] **Step 4: Implement exact validation rules**

```dart
abstract final class TrainingValidation {
  static String normalizeName(String value) =>
      value.trim().toLowerCase();

  static Map<String, String> template(WorkoutTemplateDraft draft) {
    final errors = <String, String>{};
    if (draft.name.trim().isEmpty) {
      errors['name'] = 'Enter a Template name';
    }
    if (draft.prescriptions.isEmpty) {
      errors['prescriptions'] = 'Add at least one exercise';
    }
    for (var index = 0; index < draft.prescriptions.length; index++) {
      if (draft.prescriptions[index].plannedSets.isEmpty) {
        errors['prescriptions.$index.plannedSets'] =
            'Add at least one set';
      }
    }
    return errors;
  }

  static Map<String, String> routine(RoutineDraft draft) {
    final errors = <String, String>{};
    if (draft.name.trim().isEmpty) {
      errors['name'] = 'Enter a Routine name';
    }
    if (draft.templates.isEmpty) {
      errors['templates'] = 'Add at least one Template';
    }
    final names = <String>{};
    for (var index = 0; index < draft.templates.length; index++) {
      final normalized = normalizeName(draft.templates[index].name);
      if (!names.add(normalized)) {
        errors['templates.$index.name'] =
            'Template names must be unique inside this Routine';
      }
    }
    return errors;
  }
}
```

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/training/domain/training_validation_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/src/features/training/domain test/features/training/domain
git commit -m "feat(training): define Training domain rules"
```

### Task 3: Standalone Template Repository

**Files:**
- Create: `lib/src/features/training/data/training_repository.dart`
- Create: `lib/src/features/training/data/drift_training_repository.dart`
- Create: `test/features/training/data/drift_template_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, Training domain values
- Produces: `watchTemplates`, `loadTemplate`, `saveTemplate`, `latestPrescription`, `setTemplateArchived`

- [ ] **Step 1: Write failing repository tests**

Create tests using `createTestDatabase()`:

```dart
late AppDatabase db;
late DriftTrainingRepository repo;

setUp(() {
  db = createTestDatabase();
  repo = DriftTrainingRepository(db, now: () => DateTime(2026));
});

tearDown(() => db.close());

test('saves, watches, searches, and archives standalone Templates', () async {
  final exerciseId = await db.into(db.exercises).insert(
        ExercisesCompanion.insert(name: 'Bench Press'),
      );
  final stream = repo.watchTemplates(archived: false, query: 'bench');

  final id = await repo.saveTemplate(
    WorkoutTemplateDraft(
      name: 'Chest',
      prescriptions: [
        ExercisePrescriptionDraft(
          exerciseId: exerciseId,
          exerciseName: 'Bench Press',
          plannedSets: const [PlannedSetDraft()],
        ),
      ],
    ),
  );

  expect((await stream.first).single.id, id);
  await repo.setTemplateArchived(id, archived: true);
  expect(await repo.watchTemplates(archived: false).first, isEmpty);
  expect((await repo.watchTemplates(archived: true).first).single.id, id);
});

test('latest prescription is copied, not aliased', () async {
  final exerciseId = await db.into(db.exercises).insert(
        ExercisesCompanion.insert(name: 'Bench Press'),
      );
  await repo.saveTemplate(
    WorkoutTemplateDraft(
      name: 'Chest',
      prescriptions: [
        ExercisePrescriptionDraft(
          exerciseId: exerciseId,
          exerciseName: 'Bench Press',
          notes: 'Pause',
          plannedSets: const [
            PlannedSetDraft(minReps: 8, maxReps: 12),
          ],
        ),
      ],
    ),
  );

  final latest = await repo.latestPrescription(exerciseId);

  expect(latest?.id, isNull);
  expect(latest?.notes, 'Pause');
  expect(latest?.plannedSets.single.id, isNull);
});
```

Also test case-insensitive standalone name rejection across active and archived rows, plus `updatedAt` descending sort.

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/features/training/data/drift_template_repository_test.dart`

Expected: FAIL because the repository does not exist.

- [ ] **Step 3: Define the repository contract and failures**

```dart
final class DuplicateTrainingName implements Exception {
  const DuplicateTrainingName(this.field, this.message);
  final String field;
  final String message;
}

final class InvalidTrainingDraft implements Exception {
  const InvalidTrainingDraft(this.errors);
  final Map<String, String> errors;
}

abstract interface class TrainingRepository {
  Stream<List<WorkoutTemplateSummary>> watchTemplates({
    required bool archived,
    String query = '',
  });

  Future<WorkoutTemplateDraft?> loadTemplate(int id);
  Future<int> saveTemplate(WorkoutTemplateDraft draft);
  Future<ExercisePrescriptionDraft?> latestPrescription(int exerciseId);
  Future<void> setTemplateArchived(
    int id, {
    required bool archived,
  });

  Stream<List<RoutineSummary>> watchRoutines({
    required bool archived,
    String query = '',
  });

  Future<RoutineDraft?> loadRoutine(int id);
  Future<int> saveRoutine(RoutineDraft draft);
  Future<int> saveRoutineTemplateAsStandalone(int templateId);
  Future<void> setRoutineArchived(
    int id, {
    required bool archived,
  });
}
```

- [ ] **Step 4: Implement standalone Template persistence**

`DriftTrainingRepository` accepts `AppDatabase` and injectable `DateTime Function() now`. Implement:

```dart
final class DriftTrainingRepository implements TrainingRepository {
  DriftTrainingRepository(
    this._db, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  @override
  Future<int> saveTemplate(WorkoutTemplateDraft draft) async {
    final structuralErrors = TrainingValidation.template(draft);
    if (structuralErrors.isNotEmpty) {
      throw InvalidTrainingDraft(structuralErrors);
    }
    await _assertTemplateNameAvailable(draft);
    return _db.transaction(() async {
      final timestamp = _now();
      final templateId = draft.id == null
          ? await _db.into(_db.workoutTemplates).insert(
                WorkoutTemplatesCompanion.insert(
                  name: draft.name.trim(),
                  routineId: Value(draft.routineId),
                  position: const Value.absent(),
                  createdAt: Value(timestamp),
                  updatedAt: Value(timestamp),
                ),
              )
          : draft.id!;
      if (draft.id != null) {
        await (_db.update(_db.workoutTemplates)
              ..where((row) => row.id.equals(templateId)))
            .write(
          WorkoutTemplatesCompanion(
            name: Value(draft.name.trim()),
            updatedAt: Value(timestamp),
          ),
        );
      }
      await _replacePrescriptions(templateId, draft.prescriptions, timestamp);
      return templateId;
    });
  }
}
```

`_replacePrescriptions` deletes existing child Planned Sets and Exercise Prescriptions, then inserts prescriptions and sets in list order. `loadTemplate` selects the parent, maps `archivedAt`, joins Exercise names by `exerciseId`, and orders both child levels by `position`.

`watchTemplates` watches a left join across standalone active/archived Templates, prescriptions, and Exercises; group rows by Template ID, sort summaries by `updatedAt` descending, then filter normalized Template and Exercise names in Dart.

`latestPrescription` selects Exercise Prescriptions by `exerciseId`, orders `updatedAt` descending, loads Planned Sets, returns `deepCopy()`, and therefore clears every persisted child identity.

`_assertTemplateNameAvailable` checks every standalone Template, including archived rows, because standalone names are globally unique. `setTemplateArchived` only accepts standalone Templates and writes `archivedAt` plus `updatedAt`; restore cannot introduce a name conflict.

- [ ] **Step 5: Run repository tests**

Run: `flutter test test/features/training/data/drift_template_repository_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/src/features/training/data test/features/training/data/drift_template_repository_test.dart
git commit -m "feat(training): persist standalone Templates"
```

### Task 4: Routine Repository and Copy Isolation

**Files:**
- Modify: `lib/src/features/training/data/drift_training_repository.dart`
- Create: `test/features/training/data/drift_routine_repository_test.dart`

**Interfaces:**
- Produces: `watchRoutines`, `loadRoutine`, `saveRoutine`, `saveRoutineTemplateAsStandalone`, `setRoutineArchived`
- Guarantees: deep-copy isolation and atomic Routine aggregate writes

- [ ] **Step 1: Write failing copy-isolation tests**

```dart
late AppDatabase db;
late DriftTrainingRepository repo;
late WorkoutTemplateDraft chestTemplate;

setUp(() async {
  db = createTestDatabase();
  repo = DriftTrainingRepository(db, now: () => DateTime(2026));
  final exerciseId = await db.into(db.exercises).insert(
        ExercisesCompanion.insert(name: 'Bench Press'),
      );
  chestTemplate = WorkoutTemplateDraft(
    name: 'Chest',
    prescriptions: [
      ExercisePrescriptionDraft(
        exerciseId: exerciseId,
        exerciseName: 'Bench Press',
        plannedSets: const [
          PlannedSetDraft(minReps: 8, maxReps: 12),
        ],
      ),
    ],
  );
});

tearDown(() => db.close());

test('Routine save deep-copies a standalone Template', () async {
  final standaloneId = await repo.saveTemplate(chestTemplate);
  final source = await repo.loadTemplate(standaloneId);

  final routineId = await repo.saveRoutine(
    RoutineDraft(
      name: 'PPL',
      templates: [source!.deepCopy()],
    ),
  );
  final routine = await repo.loadRoutine(routineId);
  final owned = routine!.templates.single;

  expect(owned.id, isNot(standaloneId));
  expect(owned.routineId, routineId);

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

test('Save copy to Templates creates another independent aggregate', () async {
  final routineId = await repo.saveRoutine(
    RoutineDraft(name: 'PPL', templates: [chestTemplate]),
  );
  final ownedId = (await repo.loadRoutine(routineId))!.templates.single.id!;

  final standaloneId =
      await repo.saveRoutineTemplateAsStandalone(ownedId);

  expect(standaloneId, isNot(ownedId));
  expect((await repo.loadTemplate(standaloneId))!.routineId, isNull);
});
```

Also test:

- Routine names are unique case-insensitively among active Routines.
- Template names are unique case-insensitively inside one Routine.
- Removing an owned Template sets its `archivedAt` instead of deleting it.
- Archiving a Routine hides it without changing standalone Templates.
- `watchRoutines(query:)` matches Routine and contained Template names.

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/features/training/data/drift_routine_repository_test.dart`

Expected: FAIL because Routine methods are not implemented.

- [ ] **Step 3: Implement atomic Routine save**

Use one transaction:

```dart
@override
Future<int> saveRoutine(RoutineDraft draft) async {
  final structuralErrors = TrainingValidation.routine(draft);
  if (structuralErrors.isNotEmpty) {
    throw InvalidTrainingDraft(structuralErrors);
  }
  await _assertRoutineNameAvailable(draft);
  return _db.transaction(() async {
    final timestamp = _now();
    final routineId = await _upsertRoutine(draft, timestamp);
    final existingIds = await _activeRoutineTemplateIds(routineId);
    final keptIds = <int>{};

    for (var index = 0; index < draft.templates.length; index++) {
      final source = draft.templates[index];
      final owned = source.routineId == routineId
          ? source
          : source.deepCopy(routineId: routineId);
      final templateId = await _saveOwnedTemplate(
        owned,
        routineId: routineId,
        position: index,
        timestamp: timestamp,
      );
      keptIds.add(templateId);
    }

    for (final removedId in existingIds.difference(keptIds)) {
      await (_db.update(_db.workoutTemplates)
            ..where((row) => row.id.equals(removedId)))
          .write(WorkoutTemplatesCompanion(archivedAt: Value(timestamp)));
    }
    return routineId;
  });
}
```

`_saveOwnedTemplate` must insert new identities for copied Templates and every child. Existing owned Templates may retain the parent ID while `_replacePrescriptions` replaces children. It must write `routineId`, `position`, `updatedAt`, and clear `archivedAt`.

- [ ] **Step 4: Implement Routine reads, search, archive, and standalone copy**

`watchRoutines` watches Routines joined with active owned Templates, maps ordered Template-name previews, sorts by Routine `updatedAt` descending, and filters normalized Routine/Template names.

`loadRoutine` loads active owned Templates ordered by `position`.

`saveRoutineTemplateAsStandalone` must:

```dart
@override
Future<int> saveRoutineTemplateAsStandalone(int templateId) async {
  final source = await loadTemplate(templateId);
  if (source == null || source.routineId == null) {
    throw StateError('Routine-owned Template not found');
  }
  return saveTemplate(source.deepCopy());
}
```

Before saving, resolve a standalone-name conflict by throwing `DuplicateTrainingName('name', 'A Template with this name already exists')`; do not silently rename.

`setRoutineArchived` checks restore-name conflicts and updates only the Routine `archivedAt` and `updatedAt`.

- [ ] **Step 5: Run all repository tests**

Run: `flutter test test/features/training/data`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/src/features/training/data/drift_training_repository.dart test/features/training/data/drift_routine_repository_test.dart
git commit -m "feat(training): persist Routines as isolated copies"
```

### Task 5: Training Lists, Tabs, Search, and Archives

**Files:**
- Create: `lib/src/features/training/presentation/training_providers.dart`
- Create: `lib/src/features/training/presentation/training_screen.dart`
- Create: `lib/src/features/training/presentation/archived_training_screen.dart`
- Create: `lib/src/features/training/presentation/widgets/training_list_cards.dart`
- Create: `lib/src/features/training/presentation/widgets/training_list_state.dart`
- Create: `test/support/fake_training_repository.dart`
- Create: `test/features/training/presentation/training_screen_test.dart`

**Interfaces:**
- Consumes: `TrainingRepository`
- Produces: `TrainingScreen`
- Produces callbacks: `onCreateTemplate`, `onCreateRoutine`, `onOpenTemplate`, `onOpenRoutine`

- [ ] **Step 1: Create a deterministic fake repository**

Implement every `TrainingRepository` method. Keep current Template and Routine lists in memory; each watch method must yield the current filtered value before forwarding later broadcast-controller updates. Record archive/save/copy calls in public lists.

The constructor must accept:

```dart
FakeTrainingRepository({
  List<WorkoutTemplateSummary> templates = const [],
  List<RoutineSummary> routines = const [],
});
```

Expose these controls for later controller tests:

```dart
final latestByExercise = <int, ExercisePrescriptionDraft>{};
Object? saveError;
Object? routineSaveError;
final archivedTemplateIds = <int>[];
final archivedRoutineIds = <int>[];
```

`latestPrescription` returns `latestByExercise[exerciseId]?.deepCopy()`. Save methods throw the configured error when present.

- [ ] **Step 2: Write failing Training screen tests**

```dart
Future<void> pumpTraining(
  WidgetTester tester, {
  VoidCallback? onCreateTemplate,
  VoidCallback? onCreateRoutine,
}) async {
  final fake = FakeTrainingRepository(
    templates: [
      WorkoutTemplateSummary(
        id: 1,
        name: 'Chest',
        exerciseNames: const ['Bench Press'],
        updatedAt: DateTime(2026, 1, 2),
      ),
      WorkoutTemplateSummary(
        id: 2,
        name: 'Legs',
        exerciseNames: const ['Squat'],
        updatedAt: DateTime(2026, 1, 1),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        trainingRepositoryProvider.overrideWithValue(fake),
      ],
      child: MaterialApp(
        home: TrainingScreen(
          onCreateTemplate: onCreateTemplate ?? () {},
          onCreateRoutine: onCreateRoutine ?? () {},
          onOpenTemplate: (_) {},
          onOpenRoutine: (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
}

testWidgets('Templates is initial tab and plus creates Template', (tester) async {
  var createdTemplates = 0;
  await pumpTraining(
    tester,
    onCreateTemplate: () => createdTemplates++,
  );

  expect(find.text('Templates'), findsOneWidget);
  await tester.tap(find.byTooltip('Create Template'));
  expect(createdTemplates, 1);
});

testWidgets('Routines tab changes plus action', (tester) async {
  var createdRoutines = 0;
  await pumpTraining(
    tester,
    onCreateRoutine: () => createdRoutines++,
  );

  await tester.tap(find.text('Routines'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Create Routine'));
  expect(createdRoutines, 1);
});

testWidgets('search matches contained names', (tester) async {
  await pumpTraining(tester);
  await tester.tap(find.byTooltip('Search Training'));
  await tester.enterText(find.byType(TextField), 'bench');
  await tester.pump();

  expect(find.text('Chest'), findsOneWidget);
  expect(find.text('Legs'), findsNothing);
});
```

Also cover loading skeleton keys, empty-library copy, no-result copy, retry, recently-updated order, card previews, and archived restore.

- [ ] **Step 3: Run tests to verify failure**

Run: `flutter test test/features/training/presentation/training_screen_test.dart`

Expected: FAIL because Training presentation files do not exist.

- [ ] **Step 4: Add Riverpod providers**

```dart
final trainingRepositoryProvider = Provider<TrainingRepository>((ref) {
  return DriftTrainingRepository(ref.watch(databaseProvider));
});

typedef TrainingListQuery = ({bool archived, String query});

final templateSummariesProvider = StreamProvider.family<
    List<WorkoutTemplateSummary>, TrainingListQuery>((ref, request) {
  return ref.watch(trainingRepositoryProvider).watchTemplates(
        archived: request.archived,
        query: request.query,
      );
});

final routineSummariesProvider =
    StreamProvider.family<List<RoutineSummary>, TrainingListQuery>(
  (ref, request) {
    return ref.watch(trainingRepositoryProvider).watchRoutines(
          archived: request.archived,
          query: request.query,
        );
  },
);
```

- [ ] **Step 5: Implement the Training screen state**

`TrainingScreen` is a `ConsumerStatefulWidget` with:

```dart
const TrainingScreen({
  super.key,
  required this.onCreateTemplate,
  required this.onCreateRoutine,
  required this.onOpenTemplate,
  required this.onOpenRoutine,
});

final VoidCallback onCreateTemplate;
final VoidCallback onCreateRoutine;
final ValueChanged<int> onOpenTemplate;
final ValueChanged<int> onOpenRoutine;
```

Use `TabController(length: 2, initialIndex: 0)`, one search controller, and two `PageStorageKey<String>` list keys. App-bar action tooltip and callback must derive from the selected tab. Search and overflow remain visible on both tabs.

Use `TabBarView` with `WorkoutTemplateCard` and `RoutineCard`. Each card exposes semantic labels such as `Chest, 3 exercises` and `PPL, 3 Templates`.

`ArchivedTrainingScreen` receives the selected content type, watches `archived: true`, and calls the matching restore method after confirmation.

- [ ] **Step 6: Run Training list tests**

Run: `flutter test test/features/training/presentation/training_screen_test.dart`

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/src/features/training/presentation test/support/fake_training_repository.dart test/features/training/presentation/training_screen_test.dart
git commit -m "feat(training): add Training lists and archives"
```

### Task 6: Template Editor Controller

**Files:**
- Create: `lib/src/features/training/presentation/template/template_editor_controller.dart`
- Create: `test/features/training/presentation/template_editor_controller_test.dart`

**Interfaces:**
- Consumes: `TrainingRepository`
- Produces: `TemplateEditorController`
- Produces: immutable `draft`, `errors`, `saving`, `dirty`

- [ ] **Step 1: Write failing controller tests**

```dart
const usedBenchPrescription = ExercisePrescriptionDraft(
  exerciseId: 7,
  exerciseName: 'Bench Press',
  notes: 'Pause',
  plannedSets: [PlannedSetDraft(minReps: 8, maxReps: 12)],
);

const validTemplate = WorkoutTemplateDraft(
  name: 'Chest',
  prescriptions: [usedBenchPrescription],
);

test('first-time Exercise receives one blank Planned Set', () async {
  final controller = TemplateEditorController(
    repository: fake,
    initial: const WorkoutTemplateDraft(name: '', prescriptions: []),
  );

  await controller.addExercises([
    const ExerciseChoice(id: 7, name: 'Bench Press'),
  ]);

  expect(controller.draft.prescriptions.single.plannedSets, const [
    PlannedSetDraft(),
  ]);
});

test('used Exercise receives a deep copy of latest prescription', () async {
  fake.latestByExercise[7] = usedBenchPrescription;
  final controller = TemplateEditorController(
    repository: fake,
    initial: const WorkoutTemplateDraft(name: '', prescriptions: []),
  );

  await controller.addExercises([
    const ExerciseChoice(id: 7, name: 'Bench Press'),
  ]);

  expect(controller.draft.prescriptions.single.notes, 'Pause');
  expect(controller.draft.prescriptions.single.id, isNull);
});

test('failed save retains dirty draft and exposes field errors', () async {
  fake.saveError = const DuplicateTrainingName(
    'name',
    'A Template with this name already exists',
  );
  final controller = TemplateEditorController(
    repository: fake,
    initial: validTemplate,
  );

  expect(await controller.save(), isNull);
  expect(controller.dirty, isTrue);
  expect(controller.errors['name'], contains('already exists'));
});
```

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/features/training/presentation/template_editor_controller_test.dart`

Expected: FAIL because the controller does not exist.

- [ ] **Step 3: Implement controller mutations**

`TemplateEditorController extends ChangeNotifier` and provides:

```dart
Future<void> addExercises(List<ExerciseChoice> choices);
void setName(String value);
void setNotes(int prescriptionIndex, String value);
void addPlannedSet(int prescriptionIndex);
void updatePlannedSet(
  int prescriptionIndex,
  int setIndex,
  PlannedSetDraft value,
);
void removePlannedSet(int prescriptionIndex, int setIndex);
void reorderPlannedSets(int prescriptionIndex, int oldIndex, int newIndex);
void reorderExercises(int oldIndex, int newIndex);
void removeExercise(int index);
WorkoutTemplateDraft? completeDraft();
Future<int?> save();
```

`addExercises` calls `latestPrescription` for each selected Exercise in selection order. It appends `latest.deepCopy()` when found or a new prescription with one blank Planned Set.

`completeDraft` applies `TrainingValidation.template`, returns the valid draft without persistence, and otherwise updates `errors`. `save` performs the same validation, then calls `repository.saveTemplate`. It catches `DuplicateTrainingName` and `InvalidTrainingDraft`, maps their messages into `errors`, never clears the draft on failure, and sets `dirty = false` only on success.

- [ ] **Step 4: Run controller tests**

Run: `flutter test test/features/training/presentation/template_editor_controller_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/features/training/presentation/template/template_editor_controller.dart test/features/training/presentation/template_editor_controller_test.dart
git commit -m "feat(training): manage Template editor drafts"
```

### Task 7: Exercise Picker and Template Editor UI

**Files:**
- Create: `lib/src/features/training/presentation/template/exercise_picker_screen.dart`
- Create: `lib/src/features/training/presentation/template/template_editor_screen.dart`
- Create: `lib/src/features/training/presentation/widgets/accessible_reorder_handle.dart`
- Create: `test/features/training/presentation/exercise_picker_screen_test.dart`
- Create: `test/features/training/presentation/template_editor_screen_test.dart`

**Interfaces:**
- Consumes: `exercisesProvider`, `TemplateEditorController`
- Produces: selected `List<ExerciseChoice>`
- Produces: saved Template ID through `ValueChanged<int> onSaved`

- [ ] **Step 1: Write failing picker tests**

Test that:

- search matches Exercise name;
- muscle, equipment, and type filters combine;
- tapping rows toggles selection;
- sticky action reads `Add 3 exercises`;
- confirm returns selection order;
- catalog error preserves query and selected IDs after Retry.

Use concrete seeded `Exercise` values and override `exercisesProvider`.

- [ ] **Step 2: Write failing editor widget tests**

Test:

- name and inline Planned Set fields render;
- first set may save with every target blank;
- removing the final Planned Set shows `Add at least one set`;
- drag reorder changes Exercise order;
- semantic `Move Bench Press down` action performs the same reorder;
- Planned Sets reorder through drag and semantic move actions;
- back with dirty state shows `Discard changes?`;
- failed Save focuses and announces the name error.

- [ ] **Step 3: Run tests to verify failure**

Run: `flutter test test/features/training/presentation/exercise_picker_screen_test.dart test/features/training/presentation/template_editor_screen_test.dart`

Expected: FAIL because both screens are missing.

- [ ] **Step 4: Implement the full-screen multi-select picker**

`ExercisePickerScreen` accepts:

```dart
const ExercisePickerScreen({
  super.key,
  required this.initiallySelectedIds,
});

final Set<int> initiallySelectedIds;
```

Return `List<ExerciseChoice>` with `Navigator.pop`. Use a search field, `FilterChip`s for muscle/equipment/type, checkbox rows, and:

```dart
SafeArea(
  child: FilledButton(
    onPressed: selected.isEmpty ? null : () => Navigator.pop(context, choices),
    child: Text('Add ${selected.length} exercises'),
  ),
)
```

- [ ] **Step 5: Implement inline Template editing**

`TemplateEditorScreen` owns/disposes `TemplateEditorController`, uses `PopScope` for discard confirmation, and exposes two explicit modes:

```dart
const TemplateEditorScreen.persisted({
  super.key,
  required this.initial,
  required this.repository,
  required this.onSaved,
}) : onCompleted = null;

const TemplateEditorScreen.embedded({
  super.key,
  required this.initial,
  required this.repository,
  required this.onCompleted,
}) : onSaved = null;

final WorkoutTemplateDraft initial;
final TrainingRepository repository;
final ValueChanged<int>? onSaved;
final ValueChanged<WorkoutTemplateDraft>? onCompleted;
```

Persisted mode calls `controller.save()` and returns the saved ID. Embedded mode calls `controller.completeDraft()` and returns the validated unsaved aggregate. Both modes use the repository only to prefill latest Exercise Prescriptions.

Render Exercises with `ReorderableListView`, stable keys based on persisted ID or Exercise ID, notes field, and Planned Set rows containing optional Weight, min/max reps, RIR, and Working/Dropset controls.

`AccessibleReorderHandle` must combine `ReorderableDragStartListener` with `Semantics.customSemanticsActions` for move up/down and a minimum 48×48 hit target.

Save button calls the selected completion mode; while saving, disable mutations and show an inline progress indicator without replacing the draft. Selection, Dropset, validation, and error states use text or icons in addition to color.

- [ ] **Step 6: Run picker and editor tests**

Run: `flutter test test/features/training/presentation/exercise_picker_screen_test.dart test/features/training/presentation/template_editor_screen_test.dart`

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/src/features/training/presentation/template lib/src/features/training/presentation/widgets/accessible_reorder_handle.dart test/features/training/presentation/exercise_picker_screen_test.dart test/features/training/presentation/template_editor_screen_test.dart
git commit -m "feat(training): build Template creation flow"
```

### Task 8: Template Detail and Archive Flow

**Files:**
- Create: `lib/src/features/training/presentation/template/template_detail_screen.dart`
- Create: `test/features/training/presentation/template_detail_screen_test.dart`

**Interfaces:**
- Consumes: `TrainingRepository.loadTemplate`
- Produces callbacks: `onStartWorkout`, `onEdit`, `onArchived`

- [ ] **Step 1: Write failing detail tests**

Test that active detail:

- renders ordered Exercises, Planned Sets, notes, and type;
- exposes `Start Workout`, `Edit`, and `Archive`;
- confirms Archive;
- calls `onStartWorkout` exactly once.

Test that archived detail:

- exposes Restore;
- hides Start Workout;
- restores through the repository.

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/features/training/presentation/template_detail_screen_test.dart`

Expected: FAIL because Template detail is missing.

- [ ] **Step 3: Implement read-first detail**

```dart
const TemplateDetailScreen({
  super.key,
  required this.templateId,
  required this.repository,
  required this.onStartWorkout,
  required this.onEdit,
  required this.onArchived,
});

final int templateId;
final TrainingRepository repository;
final VoidCallback onStartWorkout;
final ValueChanged<WorkoutTemplateDraft> onEdit;
final VoidCallback onArchived;
```

Load once on entry, retain the last successful value while archive/restore writes run, and show Retry on load failure. Use ordered cards; do not render Calendar dates or status.

- [ ] **Step 4: Define coordinator behavior**

Task 11's `TrainingDestination` pushes `TemplateDetailScreen`; its Edit action pushes `TemplateEditorScreen` and reloads detail after save. Until Workout Tracker lands, it routes `onStartWorkout` to one explicit unavailable message; do not create Workout persistence in this feature.

- [ ] **Step 5: Run detail tests**

Run: `flutter test test/features/training/presentation/template_detail_screen_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/src/features/training/presentation/template/template_detail_screen.dart test/features/training/presentation/template_detail_screen_test.dart
git commit -m "feat(training): add Template detail and archive"
```

### Task 9: Routine Editor and Template Picker

**Files:**
- Create: `lib/src/features/training/presentation/routine/routine_editor_controller.dart`
- Create: `lib/src/features/training/presentation/routine/routine_editor_screen.dart`
- Create: `lib/src/features/training/presentation/routine/template_picker_sheet.dart`
- Create: `test/features/training/presentation/routine_editor_controller_test.dart`
- Create: `test/features/training/presentation/routine_editor_screen_test.dart`

**Interfaces:**
- Consumes: `TrainingRepository.watchTemplates`, `saveRoutine`
- Produces: Routine draft with independent owned Template copies

- [ ] **Step 1: Write failing controller tests**

Test:

- selected standalone Templates append as `deepCopy()` values;
- creating inside a Routine sets no standalone identity;
- duplicate names inside one Routine block save;
- reorder persists list order;
- removal changes only the Routine draft;
- save failure retains all copied drafts.

- [ ] **Step 2: Write failing widget tests**

Test:

- `Add template` opens the sheet;
- sheet multi-selects existing standalone Templates;
- `Create new` opens Template editor in Routine-owned mode;
- Save requires name plus one Template;
- accessible move actions mirror drag order;
- discard confirmation protects changes.

- [ ] **Step 3: Run tests to verify failure**

Run: `flutter test test/features/training/presentation/routine_editor_controller_test.dart test/features/training/presentation/routine_editor_screen_test.dart`

Expected: FAIL because Routine editor files do not exist.

- [ ] **Step 4: Implement Routine editor controller**

Expose:

```dart
void setName(String value);
void addExistingTemplates(List<WorkoutTemplateDraft> selected);
void addCreatedTemplate(WorkoutTemplateDraft created);
void removeTemplate(int index);
void reorderTemplates(int oldIndex, int newIndex);
Future<int?> save();
```

Both add methods append independent drafts. `addExistingTemplates` always calls `deepCopy()`. `save` runs `TrainingValidation.routine`, calls `saveRoutine`, and retains dirty state on every failure.

- [ ] **Step 5: Implement picker sheet and editor**

`TemplatePickerSheet` watches active standalone Templates, supports multi-select, and returns selected full drafts after loading each chosen ID. It includes `Create new`, which pushes `TemplateEditorScreen.embedded`; the validated Routine-only draft returns to the sheet without calling `saveTemplate`.

`RoutineEditorScreen` renders name, ordered Template previews, visible drag handles, semantic move actions, `Add template`, explicit Save, and discard confirmation.

- [ ] **Step 6: Run Routine editor tests**

Run: `flutter test test/features/training/presentation/routine_editor_controller_test.dart test/features/training/presentation/routine_editor_screen_test.dart`

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/src/features/training/presentation/routine test/features/training/presentation/routine_editor_controller_test.dart test/features/training/presentation/routine_editor_screen_test.dart
git commit -m "feat(training): build Routine creation flow"
```

### Task 10: Routine Detail, Owned Template Editing, and Save Copy

**Files:**
- Create: `lib/src/features/training/presentation/routine/routine_detail_screen.dart`
- Create: `test/features/training/presentation/routine_detail_screen_test.dart`

**Interfaces:**
- Consumes: `loadRoutine`, `setRoutineArchived`, `saveRoutineTemplateAsStandalone`
- Opens: Routine-owned `TemplateDetailScreen`

- [ ] **Step 1: Write failing Routine detail tests**

Test:

- ordered Template names render;
- no `Start Routine`, Active Routine, date, or Calendar state exists;
- tapping owned Template opens its detail;
- owned detail can Start Workout and Edit only that copy;
- `Save copy to Templates` creates standalone data and reports success;
- Archive and Restore preserve owned Templates.

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/features/training/presentation/routine_detail_screen_test.dart`

Expected: FAIL because Routine detail does not exist.

- [ ] **Step 3: Implement Routine detail**

```dart
const RoutineDetailScreen({
  super.key,
  required this.routineId,
  required this.repository,
  required this.onStartWorkout,
  required this.onEdit,
});

final int routineId;
final TrainingRepository repository;
final ValueChanged<int> onStartWorkout;
final ValueChanged<RoutineDraft> onEdit;
```

Load Routine detail including `archivedAt`, render ordered Template cards, push `TemplateDetailScreen` for each owned Template, and expose Routine Edit plus archive/restore in overflow.

On `Save copy to Templates`, call `saveRoutineTemplateAsStandalone`; show a success SnackBar containing the copied Template name. Surface duplicate standalone-name failure inline and preserve the owned Template.

- [ ] **Step 4: Define coordinator behavior**

Task 11's `TrainingDestination` connects `TrainingScreen` Routine cards and context-sensitive `+` to `RoutineDetailScreen` and `RoutineEditorScreen`. After save/archive/restore, pop only the completed child route and let repository streams refresh lists.

- [ ] **Step 5: Run Routine detail tests**

Run: `flutter test test/features/training/presentation/routine_detail_screen_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/src/features/training/presentation/routine/routine_detail_screen.dart test/features/training/presentation/routine_detail_screen_test.dart
git commit -m "feat(training): add Routine detail and copy actions"
```

### Task 11: App Shell Integration and Final Verification

**Files:**
- Create: `lib/src/core/navigation/app_shell.dart`
- Create: `lib/src/features/training/presentation/training_destination.dart`
- Modify: `lib/app.dart`
- Delete: `lib/src/features/dashboard/presentation/dashboard_screen.dart`
- Modify: `test/widget_test.dart`
- Create: `test/core/navigation/app_shell_test.dart`

**Interfaces:**
- Produces: `AppShell(initialIndex, home, training, calendar)`
- App initially selects Training (`initialIndex: 1`) until Home is merged last.

- [ ] **Step 1: Write failing shell tests**

```dart
testWidgets('shell preserves Training state across destinations', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AppShell(
        initialIndex: 1,
        home: const Text('Home unavailable'),
        training: const Material(
          child: TextField(key: Key('trainingQuery')),
        ),
        calendar: const Text('Calendar unavailable'),
      ),
    ),
  );

  await tester.enterText(find.byKey(const Key('trainingQuery')), 'bench');
  await tester.tap(find.text('Calendar'));
  await tester.tap(find.text('Training'));

  final editable = tester.widget<EditableText>(find.byType(EditableText));
  expect(editable.controller.text, 'bench');
});
```

Also assert destinations are exactly Home, Training, Calendar and the current incremental app starts on Training after sync.

Add a second shell test using the real `TrainingScreen`: select Routines, enter a query, scroll the Routine list, switch to Calendar, return to Training, and assert the Routines tab, query text, and scroll offset are unchanged.

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/core/navigation/app_shell_test.dart test/widget_test.dart`

Expected: FAIL because `AppShell` does not exist.

- [ ] **Step 3: Implement the state-preserving shell**

```dart
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.initialIndex,
    required this.home,
    required this.training,
    required this.calendar,
  });

  final int initialIndex;
  final Widget home;
  final Widget training;
  final Widget calendar;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int index;

  @override
  void initState() {
    super.initState();
    index = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: [widget.home, widget.training, widget.calendar],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            label: 'Training',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'Calendar',
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Add the Training route coordinator**

`TrainingDestination` is a `ConsumerWidget`. It reads `trainingRepositoryProvider` and builds `TrainingScreen` with callbacks that push:

- persisted `TemplateEditorScreen` for `onCreateTemplate`;
- `TemplateDetailScreen` for `onOpenTemplate`;
- `RoutineEditorScreen` for `onCreateRoutine`;
- `RoutineDetailScreen` for `onOpenRoutine`.

All child routes use the same repository instance. A successful child save pops that child route; list streams refresh from Drift. Start Workout displays `Workout tracking is not available yet`.

- [ ] **Step 5: Integrate after sync**

Replace `DashboardScreen` in `app.dart` with `AppShell(initialIndex: 1)`. Pass:

- Home child: a centered `Home is not available yet` message.
- Training child: `TrainingDestination`.
- Calendar child: a centered `Calendar is not available yet` message.
- Start Workout callback: a SnackBar stating `Workout tracking is not available yet`.

These messages are explicit incremental states, not hidden no-op actions. The later Calendar and Home implementation plans replace the corresponding children and change the initial index to Home.

- [ ] **Step 6: Run focused and full verification**

Run:

```bash
dart format lib test
dart run build_runner build
flutter test test/features/training test/core/navigation/app_shell_test.dart test/widget_test.dart
flutter analyze
flutter test
```

Expected:

- formatting changes no semantics;
- generator completes without conflicting outputs;
- focused tests PASS;
- analysis reports no issues;
- complete suite PASS.

- [ ] **Step 7: Manually smoke-test dev flavor**

Run: `flutter run --flavor dev`

Verify:

- Training opens with Templates selected.
- Both lists, search, archive, editors, detail, copy, and restore work offline.
- Switching bottom destinations preserves Training tab, query, and scroll.
- No Training screen exposes scheduling or Active Routine language.

- [ ] **Step 8: Commit**

```bash
git add lib/app.dart lib/src/core/navigation/app_shell.dart lib/src/features/training/presentation/training_destination.dart lib/src/features/dashboard/presentation/dashboard_screen.dart test/widget_test.dart test/core/navigation/app_shell_test.dart
git commit -m "feat(training): integrate Training destination"
```
