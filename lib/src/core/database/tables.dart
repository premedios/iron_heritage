import 'dart:convert';
import 'package:drift/drift.dart';

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
  BoolColumn get isDropset => boolean().withDefault(const Constant(false))();
}

class Workouts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get routineId => integer().nullable().references(Routines, #id)();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();
}

class ListConverter extends TypeConverter<List<String>, String> {
  const ListConverter();

  @override
  List<String> fromSql(String fromDb) {
    return (json.decode(fromDb) as List<dynamic>).cast<String>();
  }

  @override
  String toSql(List<String> value) {
    return json.encode(value);
  }
}

class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get wgerId => integer().unique().nullable()(); // The ID from Wger
  TextColumn get name => text()();

  // Metadata Columns for Smart Alternatives
  TextColumn get category => text().nullable()(); // e.g., "Arms", "Chest"
  TextColumn get primaryMuscles => text()
      .map(const ListConverter())
      .nullable()(); // e.g. ["Pectoralis major"]
  TextColumn get secondaryMuscles =>
      text().map(const ListConverter()).nullable()();
  TextColumn get equipment => text()
      .map(const ListConverter())
      .nullable()(); // e.g. ["Barbell", "Bench"]
  TextColumn get mechanic =>
      text().nullable()(); // e.g. "Compound", "Isolation"
  TextColumn get force => text().nullable()(); // e.g. "Push", "Pull", "Static"
  TextColumn get movementPattern =>
      text().nullable()(); // e.g. "Press", "Fly", "Row"
}

class WorkoutSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutId => integer().references(Workouts, #id)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  RealColumn get weight => real().nullable()(); // null for strictly bodyweight
  IntColumn get reps => integer()();
  IntColumn get rir => integer().nullable()(); // Reps in reserve
  BoolColumn get isDropset => boolean().withDefault(const Constant(false))();
  BoolColumn get isSkipped => boolean().withDefault(const Constant(false))();
}
