import 'package:flutter_test/flutter_test.dart';
import 'package:iron_heritage/src/core/database/database.dart';
import 'package:iron_heritage/src/features/exercise/domain/smart_alternatives_service.dart';

void main() {
  late SmartAlternativesService service;

  setUp(() {
    service = const SmartAlternativesService();
  });

  group('SmartAlternativesService Tests', () {
    const occupiedBarbellSquat = Exercise(
      id: 10,
      name: 'Barbell Squat',
      category: 'Legs',
      primaryMuscles: ['Quadriceps', 'Gluteus maximus'],
      secondaryMuscles: ['Hamstrings', 'Adductors', 'Erector spinae'],
      equipment: ['Barbell', 'Squat Rack'],
      mechanic: 'Compound',
      force: 'Push',
      movementPattern: 'Squat',
    );

    const legPress = Exercise(
      id: 11,
      name: 'Leg Press',
      category: 'Legs',
      primaryMuscles: ['Quadriceps'],
      secondaryMuscles: ['Gluteus maximus', 'Hamstrings'],
      equipment: ['Machine'],
      mechanic: 'Compound',
      force: 'Push',
      movementPattern: 'Press',
    );

    const occupiedBenchPress = Exercise(
      id: 1,
      name: 'Barbell Bench Press',
      category: 'Chest',
      primaryMuscles: ['Pectoralis major'],
      secondaryMuscles: ['Anterior deltoid', 'Triceps brachii'],
      equipment: ['Barbell', 'Bench'],
      mechanic: 'Compound',
      force: 'Push',
      movementPattern: 'Press',
    );

    const dbExercises = [
      occupiedBenchPress,
      Exercise(
        id: 2,
        name: 'Dumbbell Bench Press',
        category: 'Chest',
        primaryMuscles: ['Pectoralis major'],
        equipment: ['Dumbbell', 'Bench'],
        mechanic: 'Compound',
        force: 'Push',
        movementPattern: 'Press',
      ),
      Exercise(
        id: 3,
        name: 'Smith Machine Bench Press',
        category: 'Chest',
        primaryMuscles: ['Pectoralis major'],
        equipment: ['Smith Machine', 'Bench'],
        mechanic: 'Compound',
        force: 'Push',
        movementPattern: 'Press',
      ),
      Exercise(
        id: 4,
        name: 'Push-up',
        category: 'Chest',
        primaryMuscles: ['Pectoralis major'],
        equipment: ['Bodyweight'],
        mechanic: 'Compound',
        force: 'Push',
        movementPattern: 'Press',
      ),
      Exercise(
        id: 5,
        name: 'Cable Crossover',
        category: 'Chest',
        primaryMuscles: ['Pectoralis major'],
        equipment: ['Cable'],
        mechanic: 'Isolation',
        force: 'Push',
        movementPattern: 'Fly',
      ),
    ];

    test('scores Leg Press at 70 and suggests it for Barbell Squat', () {
      expect(
        service.calculateRelevanceScore(
          occupiedExercise: occupiedBarbellSquat,
          candidate: legPress,
        ),
        70,
      );

      final results = service.findAlternatives(
        occupiedExercise: occupiedBarbellSquat,
        allExercises: [occupiedBarbellSquat, legPress],
      );

      expect(results.map((exercise) => exercise.name), contains('Leg Press'));
    });

    test(
      'includes exact and weighted matches but excludes occupied exercise',
      () {
        final results = service.findAlternatives(
          occupiedExercise: occupiedBenchPress,
          allExercises: dbExercises,
        );

        final names = results.map((e) => e.name).toList();
        expect(names, isNot(contains('Barbell Bench Press')));
        expect(
          names,
          containsAll([
            'Smith Machine Bench Press',
            'Cable Crossover',
            'Dumbbell Bench Press',
            'Push-up',
          ]),
        );
      },
    );

    test(
      'sorts according to equipment priority starting from occupied exercise equipment',
      () {
        final results = service.findAlternatives(
          occupiedExercise: occupiedBenchPress, // Equipment: Barbell
          allExercises: dbExercises,
        );

        final names = results.map((e) => e.name).toList();
        expect(
          names,
          equals([
            'Smith Machine Bench Press',
            'Cable Crossover',
            'Dumbbell Bench Press',
            'Push-up',
          ]),
        );
      },
    );

    test('sorts by equipment tier, then score, then normalized name', () {
      const smithWeighted = Exercise(
        id: 20,
        name: 'Smith Weighted',
        category: 'Chest',
        primaryMuscles: ['Pectoralis major'],
        equipment: ['Smith Machine'],
        mechanic: 'Isolation',
        force: 'Push',
        movementPattern: 'Fly',
      );
      const machineWeighted = Exercise(
        id: 21,
        name: 'Beta Weighted Machine',
        category: 'Chest',
        primaryMuscles: ['Pectoralis major'],
        equipment: ['Machine'],
        mechanic: 'Isolation',
        force: 'Push',
        movementPattern: 'Fly',
      );
      const zetaMachineExact = Exercise(
        id: 22,
        name: ' zeta Machine Exact ',
        category: 'Chest',
        primaryMuscles: ['Pectoralis major'],
        equipment: ['Machine'],
        mechanic: 'Compound',
        force: 'Push',
        movementPattern: 'Press',
      );
      const alphaMachineExact = Exercise(
        id: 23,
        name: 'Alpha Machine Exact',
        category: 'Chest',
        primaryMuscles: ['Pectoralis major'],
        equipment: ['Machine'],
        mechanic: 'Compound',
        force: 'Push',
        movementPattern: 'Press',
      );

      final results = service.findAlternatives(
        occupiedExercise: occupiedBenchPress,
        allExercises: [
          occupiedBenchPress,
          smithWeighted,
          machineWeighted,
          zetaMachineExact,
          alphaMachineExact,
        ],
      );

      expect(
        results.map((exercise) => exercise.name),
        equals([
          'Smith Weighted',
          'Alpha Machine Exact',
          ' zeta Machine Exact ',
          'Beta Weighted Machine',
        ]),
      );
    });

    test('deduplicates names and excludes occupied exercise by ID or name', () {
      const sameId = Exercise(
        id: 1,
        name: 'Renamed Occupied Exercise',
        category: 'Chest',
        primaryMuscles: ['Pectoralis major'],
        equipment: ['Machine'],
        mechanic: 'Compound',
        force: 'Push',
        movementPattern: 'Press',
      );
      const sameNormalizedName = Exercise(
        id: 30,
        name: '  barbell bench press ',
        category: 'Chest',
        primaryMuscles: ['Pectoralis major'],
        equipment: ['Machine'],
        mechanic: 'Compound',
        force: 'Push',
        movementPattern: 'Press',
      );
      const duplicateName = Exercise(
        id: 31,
        name: ' dumbbell bench press ',
        category: 'Chest',
        primaryMuscles: ['Pectoralis major'],
        equipment: ['Dumbbell'],
        mechanic: 'Compound',
        force: 'Push',
        movementPattern: 'Press',
      );

      final results = service.findAlternatives(
        occupiedExercise: occupiedBenchPress,
        allExercises: [
          occupiedBenchPress,
          sameId,
          sameNormalizedName,
          dbExercises[1],
          duplicateName,
        ],
      );

      expect(results, hasLength(1));
      expect(results.single.id, 2);
    });

    test('normalizes whitespace and case in scoring and equipment tiers', () {
      const formattedSmithPress = Exercise(
        id: 40,
        name: 'Formatted Smith Press',
        category: 'Chest',
        primaryMuscles: [' pectoralis MAJOR '],
        equipment: [' smith machine '],
        mechanic: ' compound ',
        force: ' push ',
        movementPattern: ' press ',
      );
      const bodyweightPress = Exercise(
        id: 41,
        name: 'Bodyweight Press',
        category: 'Chest',
        primaryMuscles: ['Pectoralis major'],
        equipment: ['Bodyweight'],
        mechanic: 'Compound',
        force: 'Push',
        movementPattern: 'Press',
      );

      expect(
        service.calculateRelevanceScore(
          occupiedExercise: occupiedBenchPress,
          candidate: formattedSmithPress,
        ),
        100,
      );

      final results = service.findAlternatives(
        occupiedExercise: occupiedBenchPress,
        allExercises: [
          occupiedBenchPress,
          bodyweightPress,
          formattedSmithPress,
        ],
      );

      expect(
        results.map((exercise) => exercise.name),
        equals(['Formatted Smith Press', 'Bodyweight Press']),
      );
    });

    test('applies overlap, half-credit, threshold, and missing-data rules', () {
      const secondaryOnlyMatch = Exercise(
        id: 50,
        name: 'Secondary Match',
        category: 'Chest',
        secondaryMuscles: ['Pectoralis major'],
        equipment: ['Machine'],
        mechanic: 'Compound',
        force: 'Push',
        movementPattern: 'Press',
      );
      const belowThreshold = Exercise(
        id: 51,
        name: 'Partial Squat Match',
        category: 'Legs',
        primaryMuscles: ['Quadriceps'],
        equipment: ['Machine'],
        mechanic: 'Compound',
        force: 'Push',
        movementPattern: 'Extension',
      );
      const noTargetOverlap = Exercise(
        id: 52,
        name: 'Unrelated Exact Metadata',
        category: 'Back',
        primaryMuscles: ['Latissimus dorsi'],
        equipment: ['Machine'],
        mechanic: 'Compound',
        force: 'Push',
        movementPattern: 'Squat',
      );
      const missingMetadata = Exercise(
        id: 53,
        name: 'Missing Metadata',
        category: 'Chest',
        primaryMuscles: ['Pectoralis major'],
        equipment: ['Machine'],
      );
      const occupiedWithoutTargets = Exercise(
        id: 54,
        name: 'Missing Targets',
        category: 'Chest',
        equipment: ['Barbell'],
        mechanic: 'Compound',
        force: 'Push',
        movementPattern: 'Press',
      );

      expect(
        service.calculateRelevanceScore(
          occupiedExercise: occupiedBenchPress,
          candidate: secondaryOnlyMatch,
        ),
        70,
      );
      expect(
        service.calculateRelevanceScore(
          occupiedExercise: occupiedBarbellSquat,
          candidate: belowThreshold,
        ),
        55,
      );
      expect(
        service.calculateRelevanceScore(
          occupiedExercise: occupiedBarbellSquat,
          candidate: noTargetOverlap,
        ),
        40,
      );
      expect(
        service
            .findAlternatives(
              occupiedExercise: occupiedBenchPress,
              allExercises: [
                occupiedBenchPress,
                secondaryOnlyMatch,
                missingMetadata,
              ],
            )
            .map((exercise) => exercise.name),
        equals(['Secondary Match']),
      );
      expect(
        service.findAlternatives(
          occupiedExercise: occupiedBarbellSquat,
          allExercises: [occupiedBarbellSquat, belowThreshold, noTargetOverlap],
        ),
        isEmpty,
      );
      expect(
        service.findAlternatives(
          occupiedExercise: occupiedWithoutTargets,
          allExercises: [occupiedWithoutTargets, missingMetadata],
        ),
        isEmpty,
      );
    });

    test('wraps around equipment priority when starting from Cable', () {
      const occupiedCableFly = Exercise(
        id: 5,
        name: 'Cable Crossover',
        category: 'Chest',
        primaryMuscles: ['Pectoralis major'],
        equipment: ['Cable'],
        mechanic: 'Isolation',
        force: 'Push',
        movementPattern: 'Fly',
      );

      const flyExercises = [
        occupiedCableFly,
        Exercise(
          id: 6,
          name: 'Pec Deck',
          category: 'Chest',
          primaryMuscles: ['Pectoralis major'],
          equipment: ['Machine'],
          mechanic: 'Isolation',
          force: 'Push',
          movementPattern: 'Fly',
        ),
        Exercise(
          id: 7,
          name: 'Dumbbell Fly',
          category: 'Chest',
          primaryMuscles: ['Pectoralis major'],
          equipment: ['Dumbbell', 'Bench'],
          mechanic: 'Isolation',
          force: 'Push',
          movementPattern: 'Fly',
        ),
        Exercise(
          id: 8,
          name: 'Barbell Fly Prototype',
          category: 'Chest',
          primaryMuscles: ['Pectoralis major'],
          equipment: ['Barbell'],
          mechanic: 'Isolation',
          force: 'Push',
          movementPattern: 'Fly',
        ),
        Exercise(
          id: 9,
          name: 'Bodyweight Fly Prototype',
          category: 'Chest',
          primaryMuscles: ['Pectoralis major'],
          equipment: ['Bodyweight'],
          mechanic: 'Isolation',
          force: 'Push',
          movementPattern: 'Fly',
        ),
      ];

      final results = service.findAlternatives(
        occupiedExercise: occupiedCableFly, // Equipment: Cable (index 2)
        allExercises: flyExercises,
      );

      // Core chain: Barbell (0), Smith Machine (1), Cable (2), Machine (3), Dumbbell (4).
      // Wrap starting at Cable (2): Cable (2), Machine (3), Dumbbell (4), Barbell (0), Smith Machine (1), Bodyweight (end).
      final names = results.map((e) => e.name).toList();
      expect(
        names,
        equals([
          'Pec Deck', // Machine
          'Dumbbell Fly', // Dumbbell
          'Barbell Fly Prototype', // Barbell
          'Bodyweight Fly Prototype', // Bodyweight (last resort)
        ]),
      );
    });
  });
}
