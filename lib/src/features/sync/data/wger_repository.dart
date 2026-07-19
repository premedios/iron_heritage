import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:logger/logger.dart';
import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';
import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'wger_repository.g.dart';

@riverpod
WgerRepository wgerRepository(Ref ref) {
  return WgerRepository(ref.watch(databaseProvider));
}

@riverpod
Future<bool> isSynced(Ref ref) async {
  final repo = ref.watch(wgerRepositoryProvider);
  return await repo.isSynced();
}

@riverpod
Future<void> runSync(Ref ref) async {
  final repo = ref.watch(wgerRepositoryProvider);
  await repo.syncExercises();
  // Invalidate so the app routing knows we are synced now!
  ref.invalidate(isSyncedProvider);
}

class WgerRepository {
  final AppDatabase _db;
  final _logger = Logger();
  
  WgerRepository(this._db);

  Future<bool> isSynced() async {
    final countExp = _db.exercises.id.count();
    final query = _db.selectOnly(_db.exercises)..addColumns([countExp]);
    final result = await query.map((row) => row.read(countExp)).getSingle();
    return result != null && result > 0;
  }

  /// Loads pre-loaded exercises from the local JSON asset and saves them to the local database.
  Future<void> syncExercises() async {
    try {
      final jsonString = await rootBundle.loadString('assets/seed_exercises.json');
      final List<dynamic> results = json.decode(jsonString);

      final companions = results.map((e) {
        return ExercisesCompanion.insert(
          name: e['name'] as String,
          category: Value(e['category'] as String?),
          primaryMuscles: Value(List<String>.from(e['primaryMuscles'] ?? [])),
          secondaryMuscles: Value(List<String>.from(e['secondaryMuscles'] ?? [])),
          equipment: Value(List<String>.from(e['equipment'] ?? [])),
          mechanic: Value(e['mechanic'] as String?),
          force: Value(e['force'] as String?),
          movementPattern: Value(e['movementPattern'] as String?),
        );
      }).toList();

      await _db.batch((batch) {
        batch.insertAllOnConflictUpdate(_db.exercises, companions);
      });
    } catch (e) {
      _logger.e('Failed to sync exercises: $e');
    }
  }
}
