import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';

final smartAlternativesServiceProvider = Provider<SmartAlternativesService>(
  (ref) => const SmartAlternativesService(),
);

class SmartAlternativesService {
  const SmartAlternativesService();

  static const List<String> coreEquipmentPriority = [
    'Barbell',
    'Smith Machine',
    'Cable',
    'Machine',
    'Dumbbell',
  ];

  static const String bodyweightEquipment = 'Bodyweight';

  /// Filters and sorts candidate exercises to find smart alternatives for an occupied exercise.
  List<Exercise> findAlternatives({
    required Exercise occupiedExercise,
    required List<Exercise> allExercises,
  }) {
    final occupiedMuscles = _normalizedSet(occupiedExercise.primaryMuscles);
    if (occupiedMuscles.isEmpty) return const [];

    // 1. Filter out the occupied exercise itself
    final candidates = allExercises.where((ex) {
      if (ex.id == occupiedExercise.id ||
          _normalize(ex.name) == _normalize(occupiedExercise.name)) {
        return false;
      }

      // 2. Strict Biomechanical Matching
      // Must match the complete primary-muscle set.
      final candidateMuscles = _normalizedSet(ex.primaryMuscles);
      if (!_setsEqual(occupiedMuscles, candidateMuscles)) return false;

      // Must match mechanic (Compound / Isolation) if specified
      if (occupiedExercise.mechanic != null &&
          ex.mechanic != occupiedExercise.mechanic) {
        return false;
      }

      // Must match force (Push / Pull / Static) if specified
      if (occupiedExercise.force != null &&
          ex.force != occupiedExercise.force) {
        return false;
      }

      // Must match movementPattern (Press / Fly / Row / etc.) if specified
      if (occupiedExercise.movementPattern != null &&
          ex.movementPattern != occupiedExercise.movementPattern) {
        return false;
      }

      return true;
    }).toList();

    // 3. Equipment Priority Chain Wrap-Around
    final occupiedEquipment = occupiedExercise.equipment ?? [];

    // Find the starting equipment index in core priority
    String startingEquip = occupiedEquipment.firstWhere(
      (e) => coreEquipmentPriority.contains(e),
      orElse: () => coreEquipmentPriority.first,
    );

    int startIndex = coreEquipmentPriority.indexOf(startingEquip);
    if (startIndex == -1) startIndex = 0;

    // Create the wrap-around priority list (Bodyweight always at the end as last resort)
    final wrapAroundPriority = [
      ...coreEquipmentPriority.sublist(startIndex),
      ...coreEquipmentPriority.sublist(0, startIndex),
      bodyweightEquipment,
    ];

    // 4. Sort candidates based on wrap-around priority
    candidates.sort((a, b) {
      final equipA = _getPriorityIndex(a.equipment, wrapAroundPriority);
      final equipB = _getPriorityIndex(b.equipment, wrapAroundPriority);

      return equipA.compareTo(equipB);
    });

    final uniqueCandidates = <String, Exercise>{};
    for (final candidate in candidates) {
      uniqueCandidates.putIfAbsent(_normalize(candidate.name), () => candidate);
    }

    return uniqueCandidates.values.toList();
  }

  Set<String> _normalizedSet(List<String>? values) {
    return {
      for (final value in values ?? const <String>[])
        if (_normalize(value).isNotEmpty) _normalize(value),
    };
  }

  bool _setsEqual(Set<String> a, Set<String> b) {
    return a.length == b.length && a.containsAll(b);
  }

  String _normalize(String value) => value.trim().toLowerCase();

  int _getPriorityIndex(List<String>? equipment, List<String> priorityList) {
    if (equipment == null || equipment.isEmpty) return priorityList.length;

    for (int i = 0; i < priorityList.length; i++) {
      if (equipment.contains(priorityList[i])) {
        return i;
      }
    }

    return priorityList.length;
  }
}
