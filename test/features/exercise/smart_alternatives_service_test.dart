import 'package:flutter_test/flutter_test.dart';
import 'package:iron_heritage/src/core/database/database.dart';
import 'package:iron_heritage/src/features/exercise/domain/smart_alternatives_service.dart';

void main() {
  late SmartAlternativesService service;

  setUp(() {
    service = const SmartAlternativesService();
  });

  group('SmartAlternativesService Tests', () {
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

    test('filters out occupied exercise itself and mismatched mechanic/movementPattern', () {
      final results = service.findAlternatives(
        occupiedExercise: occupiedBenchPress,
        allExercises: dbExercises,
      );

      // Should contain Dumbbell Bench Press, Smith Machine Bench Press, Push-up
      // Should NOT contain occupied exercise (Barbell Bench Press) or mismatched Fly (Cable Crossover)
      final names = results.map((e) => e.name).toList();
      expect(names, isNot(contains('Barbell Bench Press')));
      expect(names, isNot(contains('Cable Crossover')));
      expect(names, containsAll(['Smith Machine Bench Press', 'Dumbbell Bench Press', 'Push-up']));
    });

    test('sorts according to equipment priority starting from occupied exercise equipment', () {
      final results = service.findAlternatives(
        occupiedExercise: occupiedBenchPress, // Equipment: Barbell
        allExercises: dbExercises,
      );

      // Barbell occupied: Priority chain wraps starting at Barbell -> Smith Machine -> Cable -> Machine -> Dumbbell -> Bodyweight
      // Candidates: Smith Machine Bench Press (Smith Machine), Dumbbell Bench Press (Dumbbell), Push-up (Bodyweight)
      final names = results.map((e) => e.name).toList();
      expect(names, equals(['Smith Machine Bench Press', 'Dumbbell Bench Press', 'Push-up']));
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
      expect(names, equals([
        'Pec Deck', // Machine
        'Dumbbell Fly', // Dumbbell
        'Barbell Fly Prototype', // Barbell
        'Bodyweight Fly Prototype', // Bodyweight (last resort)
      ]));
    });
  });
}
