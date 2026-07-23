import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iron_heritage/src/core/database/database.dart';
import 'package:iron_heritage/src/features/exercise/presentation/exercise_list_screen.dart';
import 'package:iron_heritage/src/features/training/domain/training_models.dart';
import 'package:iron_heritage/src/features/training/presentation/template/exercise_picker_screen.dart';

const exercises = [
  Exercise(
    id: 1,
    name: 'Bench Press',
    category: 'Chest',
    primaryMuscles: ['Pectoralis major'],
    equipment: ['Barbell'],
    mechanic: 'Compound',
  ),
  Exercise(
    id: 2,
    name: 'Cable Fly',
    category: 'Chest',
    primaryMuscles: ['Pectoralis major'],
    equipment: ['Cable'],
    mechanic: 'Isolation',
  ),
  Exercise(
    id: 3,
    name: 'Barbell Row',
    category: 'Back',
    primaryMuscles: ['Latissimus dorsi'],
    equipment: ['Barbell'],
    mechanic: 'Compound',
  ),
];

Future<void> pumpPicker(
  WidgetTester tester, {
  Set<int> selected = const {},
  required Stream<List<Exercise>> Function(Ref ref) provider,
  ValueChanged<List<ExerciseChoice>?>? onResult,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [exercisesProvider.overrideWith(provider)],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                final result = await Navigator.of(context)
                    .push<List<ExerciseChoice>>(
                      MaterialPageRoute(
                        builder: (_) => ExercisePickerScreen(
                          initiallySelectedIds: selected,
                        ),
                      ),
                    );
                onResult?.call(result);
              },
              child: const Text('Open picker'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open picker'));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('search matches Exercise name', (tester) async {
    await pumpPicker(tester, provider: (_) => Stream.value(exercises));

    await tester.enterText(find.byType(SearchBar), 'cable');
    await tester.pump();

    expect(find.text('Cable Fly'), findsOneWidget);
    expect(find.text('Bench Press'), findsNothing);
    expect(find.text('Barbell Row'), findsNothing);
  });

  testWidgets('muscle, equipment, and type filters combine', (tester) async {
    await pumpPicker(tester, provider: (_) => Stream.value(exercises));

    await tester.tap(find.widgetWithText(FilterChip, 'Chest'));
    await tester.tap(find.widgetWithText(FilterChip, 'Barbell'));
    await tester.tap(find.widgetWithText(FilterChip, 'Compound'));
    await tester.pump();

    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Cable Fly'), findsNothing);
    expect(find.text('Barbell Row'), findsNothing);
  });

  testWidgets('selection toggles and confirm returns selection order', (
    tester,
  ) async {
    List<ExerciseChoice>? result;
    await pumpPicker(
      tester,
      provider: (_) => Stream.value(exercises),
      onResult: (value) => result = value,
    );

    await tester.tap(find.text('Barbell Row'));
    await tester.tap(find.text('Bench Press'));
    await tester.tap(find.text('Cable Fly'));
    await tester.pump();
    expect(find.text('Add 3 exercises'), findsOneWidget);
    await tester.tap(find.text('Bench Press'));
    await tester.pump();
    expect(find.text('Add 2 exercises'), findsOneWidget);
    await tester.tap(find.text('Bench Press'));
    await tester.pump();
    expect(find.text('Add 3 exercises'), findsOneWidget);

    await tester.tap(find.text('Add 3 exercises'));
    await tester.pumpAndSettle();

    expect(result!.map((choice) => choice.name), [
      'Barbell Row',
      'Cable Fly',
      'Bench Press',
    ]);
  });

  testWidgets('catalog Retry preserves query and selected IDs', (tester) async {
    var attempts = 0;
    await pumpPicker(
      tester,
      selected: const {1},
      provider: (_) {
        attempts++;
        return attempts == 1
            ? Stream.error(StateError('catalog unavailable'))
            : Stream.value(exercises);
      },
    );

    await tester.enterText(find.byType(SearchBar), 'bench');
    await tester.pump();
    expect(find.textContaining('catalog unavailable'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pump();
    await tester.pump();

    expect(attempts, 2);
    expect(
      tester
          .widget<CheckboxListTile>(
            find.widgetWithText(CheckboxListTile, 'Bench Press'),
          )
          .value,
      isTrue,
    );
    expect(find.text('Add 1 exercise'), findsOneWidget);
    expect(find.text('Cable Fly'), findsNothing);
  });
}
