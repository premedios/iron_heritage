import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/database/database.dart';

part 'smart_alternatives_service.g.dart';

@riverpod
SmartAlternativesService smartAlternativesService(Ref ref) {
  return const SmartAlternativesService();
}

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
    // 1. Filter out the occupied exercise itself
    final candidates = allExercises.where((ex) {
      if (ex.id == occupiedExercise.id || ex.name == occupiedExercise.name) {
        return false;
      }

      // 2. Strict Biomechanical Matching
      // Must match primary muscles
      final occupiedMuscles = occupiedExercise.primaryMuscles ?? [];
      final candidateMuscles = ex.primaryMuscles ?? [];
      final hasPrimaryMuscleMatch = candidateMuscles.any((m) => occupiedMuscles.contains(m));
      if (!hasPrimaryMuscleMatch) return false;

      // Must match mechanic (Compound / Isolation) if specified
      if (occupiedExercise.mechanic != null && ex.mechanic != occupiedExercise.mechanic) {
        return false;
      }

      // Must match force (Push / Pull / Static) if specified
      if (occupiedExercise.force != null && ex.force != occupiedExercise.force) {
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

    return candidates;
  }

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
