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
