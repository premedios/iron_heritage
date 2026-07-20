import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iron_heritage/src/core/database/database.dart';
import 'package:iron_heritage/src/features/exercise/presentation/smart_alternatives_bottom_sheet.dart';

void main() {
  const occupiedBenchPress = Exercise(
    id: 1,
    name: 'Barbell Bench Press',
    category: 'Chest',
    primaryMuscles: ['Pectoralis major'],
    equipment: ['Barbell', 'Bench'],
    mechanic: 'Compound',
    force: 'Push',
    movementPattern: 'Press',
  );

  const dumbbellBenchPress = Exercise(
    id: 2,
    name: 'Dumbbell Bench Press',
    category: 'Chest',
    primaryMuscles: ['Pectoralis major'],
    equipment: ['Dumbbell', 'Bench'],
    mechanic: 'Compound',
    force: 'Push',
    movementPattern: 'Press',
  );

  testWidgets('SmartAlternativesBottomSheet renders alternatives and skip button', (tester) async {
    Exercise? selectedAlt;
    bool skipped = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showSmartAlternativesBottomSheet(
                      context: context,
                      occupiedExercise: occupiedBenchPress,
                      allExercises: [occupiedBenchPress, dumbbellBenchPress],
                      onSelectAlternative: (alt) {
                        selectedAlt = alt;
                      },
                      onSkip: () {
                        skipped = true;
                      },
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Verify title and alternative items
    expect(find.text('Smart Alternatives'), findsOneWidget);
    expect(find.text('Dumbbell Bench Press'), findsOneWidget);
    expect(find.text('Skip Exercise'), findsOneWidget);

    // Tap alternative
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();

    expect(selectedAlt?.name, equals('Dumbbell Bench Press'));
    expect(skipped, isFalse);
  });

  testWidgets('SmartAlternativesBottomSheet handles Skip button press', (tester) async {
    bool skipped = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showSmartAlternativesBottomSheet(
                      context: context,
                      occupiedExercise: occupiedBenchPress,
                      allExercises: [occupiedBenchPress, dumbbellBenchPress],
                      onSelectAlternative: (_) {},
                      onSkip: () {
                        skipped = true;
                      },
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Tap Skip Exercise
    await tester.tap(find.text('Skip Exercise'));
    await tester.pumpAndSettle();

    expect(skipped, isTrue);
  });
}
