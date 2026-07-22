import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';

final smartAlternativesServiceProvider = Provider<SmartAlternativesService>(
  (ref) => const SmartAlternativesService(),
);

class SmartAlternativesService {
  const SmartAlternativesService();

  static const double targetMuscleWeight = 60;
  static const double mechanicWeight = 15;
  static const double forceWeight = 10;
  static const double movementPatternWeight = 15;
  static const double minimumRelevanceScore = 65;

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
    final occupiedMuscles = _normalizeAll(occupiedExercise.primaryMuscles);
    if (occupiedMuscles.isEmpty) return const [];

    // 1. Filter out the occupied exercise itself
    final candidates = allExercises.where((ex) {
      final normalizedName = _normalize(ex.name);
      if (ex.id == occupiedExercise.id ||
          normalizedName == _normalize(occupiedExercise.name)) {
        return false;
      }

      final candidateMuscles = {
        ..._normalizeAll(ex.primaryMuscles),
        ..._normalizeAll(ex.secondaryMuscles),
      };
      if (!occupiedMuscles.any(candidateMuscles.contains)) return false;

      return calculateRelevanceScore(
            occupiedExercise: occupiedExercise,
            candidate: ex,
          ) >=
          minimumRelevanceScore;
    }).toList();

    // 3. Equipment Priority Chain Wrap-Around
    final occupiedEquipment = occupiedExercise.equipment ?? [];
    final normalizedCorePriority = coreEquipmentPriority
        .map(_normalize)
        .toList();

    // Find the starting equipment index in core priority
    String startingEquip = occupiedEquipment.firstWhere(
      (equipment) => normalizedCorePriority.contains(_normalize(equipment)),
      orElse: () => normalizedCorePriority.first,
    );
    startingEquip = _normalize(startingEquip);

    int startIndex = normalizedCorePriority.indexOf(startingEquip);
    if (startIndex == -1) startIndex = 0;

    // Create the wrap-around priority list (Bodyweight always at the end as last resort)
    final wrapAroundPriority = [
      ...normalizedCorePriority.sublist(startIndex),
      ...normalizedCorePriority.sublist(0, startIndex),
      _normalize(bodyweightEquipment),
    ];

    // 4. Sort candidates based on wrap-around priority
    candidates.sort((a, b) {
      final equipA = _getPriorityIndex(a.equipment, wrapAroundPriority);
      final equipB = _getPriorityIndex(b.equipment, wrapAroundPriority);
      final equipmentComparison = equipA.compareTo(equipB);
      if (equipmentComparison != 0) return equipmentComparison;

      final scoreA = calculateRelevanceScore(
        occupiedExercise: occupiedExercise,
        candidate: a,
      );
      final scoreB = calculateRelevanceScore(
        occupiedExercise: occupiedExercise,
        candidate: b,
      );
      final scoreComparison = scoreB.compareTo(scoreA);
      if (scoreComparison != 0) return scoreComparison;

      final nameComparison = _normalize(a.name).compareTo(_normalize(b.name));
      if (nameComparison != 0) return nameComparison;

      return a.id.compareTo(b.id);
    });

    final seenCandidateNames = <String>{};
    return candidates
        .where(
          (candidate) => seenCandidateNames.add(_normalize(candidate.name)),
        )
        .toList();
  }

  /// Scores how closely [candidate] preserves the intent of [occupiedExercise].
  ///
  /// The score is a product heuristic, not a scientific equivalence measure.
  double calculateRelevanceScore({
    required Exercise occupiedExercise,
    required Exercise candidate,
  }) {
    final occupiedTargets = _normalizeAll(occupiedExercise.primaryMuscles);
    if (occupiedTargets.isEmpty) return 0;

    final candidatePrimary = _normalizeAll(candidate.primaryMuscles);
    final candidateSecondary = _normalizeAll(candidate.secondaryMuscles);
    var targetCoverageCredits = 0.0;

    for (final target in occupiedTargets) {
      if (candidatePrimary.contains(target)) {
        targetCoverageCredits += 1;
      } else if (candidateSecondary.contains(target)) {
        targetCoverageCredits += 0.5;
      }
    }

    var score =
        (targetCoverageCredits / occupiedTargets.length) * targetMuscleWeight;
    if (_matches(occupiedExercise.mechanic, candidate.mechanic)) {
      score += mechanicWeight;
    }
    if (_matches(occupiedExercise.force, candidate.force)) {
      score += forceWeight;
    }
    if (_matches(occupiedExercise.movementPattern, candidate.movementPattern)) {
      score += movementPatternWeight;
    }

    return score;
  }

  int _getPriorityIndex(List<String>? equipment, List<String> priorityList) {
    if (equipment == null || equipment.isEmpty) return priorityList.length;
    final normalizedEquipment = _normalizeAll(equipment);

    for (int i = 0; i < priorityList.length; i++) {
      if (normalizedEquipment.contains(priorityList[i])) {
        return i;
      }
    }

    return priorityList.length;
  }

  Set<String> _normalizeAll(List<String>? values) {
    if (values == null) return const {};
    return values.map(_normalize).where((value) => value.isNotEmpty).toSet();
  }

  String _normalize(String value) => value.trim().toLowerCase();

  bool _matches(String? occupiedValue, String? candidateValue) {
    if (occupiedValue == null || candidateValue == null) return false;
    final occupied = _normalize(occupiedValue);
    final candidate = _normalize(candidateValue);
    return occupied.isNotEmpty && candidate.isNotEmpty && occupied == candidate;
  }
}
