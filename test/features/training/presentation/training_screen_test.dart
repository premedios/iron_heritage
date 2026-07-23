import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iron_heritage/src/features/training/domain/training_models.dart';
import 'package:iron_heritage/src/features/training/presentation/archived_training_screen.dart';
import 'package:iron_heritage/src/features/training/presentation/training_providers.dart';
import 'package:iron_heritage/src/features/training/presentation/training_screen.dart';

import '../../../support/fake_training_repository.dart';

Future<FakeTrainingRepository> pumpTraining(
  WidgetTester tester, {
  VoidCallback? onCreateTemplate,
  VoidCallback? onCreateRoutine,
  ValueChanged<int>? onOpenTemplate,
  ValueChanged<int>? onOpenRoutine,
  List<WorkoutTemplateSummary>? templates,
  List<RoutineSummary> routines = const [],
}) async {
  final fake = FakeTrainingRepository(
    templates:
        templates ??
        [
          WorkoutTemplateSummary(
            id: 1,
            name: 'Chest',
            exerciseNames: const ['Bench Press', 'Cable Fly'],
            updatedAt: DateTime(2026, 1, 2),
          ),
          WorkoutTemplateSummary(
            id: 2,
            name: 'Legs',
            exerciseNames: const ['Squat'],
            updatedAt: DateTime(2026, 1, 1),
          ),
        ],
    routines: routines,
  );
  addTearDown(fake.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [trainingRepositoryProvider.overrideWithValue(fake)],
      child: MaterialApp(
        home: TrainingScreen(
          onCreateTemplate: onCreateTemplate ?? () {},
          onCreateRoutine: onCreateRoutine ?? () {},
          onOpenTemplate: onOpenTemplate ?? (_) {},
          onOpenRoutine: onOpenRoutine ?? (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
  return fake;
}

void main() {
  test(
    'list providers cancel repository streams after listeners close',
    () async {
      final fake = FakeTrainingRepository();
      final container = ProviderContainer(
        overrides: [trainingRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(() async {
        container.dispose();
        await fake.dispose();
      });
      final templateSubscription = container.listen(
        templateSummariesProvider((archived: false, query: 'bench')),
        (_, _) {},
      );
      final routineSubscription = container.listen(
        routineSummariesProvider((archived: true, query: 'push')),
        (_, _) {},
      );
      await container.pump();

      expect(fake.templateWatchSubscriptions, 1);
      expect(fake.routineWatchSubscriptions, 1);
      templateSubscription.close();
      routineSubscription.close();
      await container.pump();
      await Future<void>.delayed(Duration.zero);

      expect(fake.templateWatchCancellations, 1);
      expect(fake.routineWatchCancellations, 1);
    },
  );

  test('fake records copy calls and forwards configured save errors', () async {
    final fake = FakeTrainingRepository()
      ..saveError = StateError('duplicate Template');
    addTearDown(fake.dispose);

    await expectLater(
      fake.saveRoutineTemplateAsStandalone(17),
      throwsA(isA<StateError>()),
    );
    expect(fake.copiedRoutineTemplateIds, [17]);
  });

  test('fake records failed Template and Routine save attempts', () async {
    final fake = FakeTrainingRepository()
      ..saveError = StateError('Template save failed')
      ..routineSaveError = StateError('Routine save failed');
    addTearDown(fake.dispose);
    final template = WorkoutTemplateDraft(
      name: 'Chest',
      prescriptions: const [],
    );
    final routine = RoutineDraft(name: 'PPL', templates: const []);

    await expectLater(fake.saveTemplate(template), throwsA(isA<StateError>()));
    await expectLater(fake.saveRoutine(routine), throwsA(isA<StateError>()));

    expect(fake.savedTemplates, [same(template)]);
    expect(fake.savedRoutines, [same(routine)]);
  });

  testWidgets('Templates is initial tab and plus creates Template', (
    tester,
  ) async {
    var createdTemplates = 0;
    await pumpTraining(tester, onCreateTemplate: () => createdTemplates++);

    expect(find.text('Templates'), findsOneWidget);
    await tester.tap(find.byTooltip('Create Template'));
    expect(createdTemplates, 1);
  });

  testWidgets('Routines tab changes plus action', (tester) async {
    var createdRoutines = 0;
    await pumpTraining(tester, onCreateRoutine: () => createdRoutines++);

    await tester.tap(find.text('Routines'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Create Routine'));
    expect(createdRoutines, 1);
  });

  testWidgets('search matches contained names', (tester) async {
    await pumpTraining(tester);
    await tester.tap(find.byTooltip('Search Training'));
    await tester.enterText(find.byType(TextField), 'bench');
    await tester.pump();

    expect(find.text('Chest'), findsOneWidget);
    expect(find.text('Legs'), findsNothing);
  });

  testWidgets('visible close-search action announces Close Search', (
    tester,
  ) async {
    await pumpTraining(tester);

    await tester.tap(find.byTooltip('Search Training'));
    await tester.pump();

    expect(find.byTooltip('Close Search'), findsOneWidget);
    expect(find.bySemanticsLabel('Close Search'), findsOneWidget);
  });

  testWidgets('initial loading uses keyed skeleton rows', (tester) async {
    final fake = FakeTrainingRepository()..templateWatchPending = true;
    addTearDown(fake.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [trainingRepositoryProvider.overrideWithValue(fake)],
        child: MaterialApp(
          home: TrainingScreen(
            onCreateTemplate: () {},
            onCreateRoutine: () {},
            onOpenTemplate: (_) {},
            onOpenRoutine: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('template-skeleton-0')), findsOneWidget);
    expect(find.byKey(const Key('template-skeleton-2')), findsOneWidget);
  });

  testWidgets('empty library explains Templates and points to plus', (
    tester,
  ) async {
    await pumpTraining(tester, templates: const []);
    await tester.pump();

    expect(find.text('No Templates yet'), findsOneWidget);
    expect(
      find.text('Templates are individual training days. Use + to create one.'),
      findsOneWidget,
    );
  });

  testWidgets('search no-result copy differs from empty library', (
    tester,
  ) async {
    await pumpTraining(tester);
    await tester.tap(find.byTooltip('Search Training'));
    await tester.enterText(find.byType(TextField), 'deadlift');
    await tester.pump();

    expect(find.text('No Templates match “deadlift”'), findsOneWidget);
    expect(find.text('No Templates yet'), findsNothing);
  });

  testWidgets('list error gives reason and retries the retained query', (
    tester,
  ) async {
    final fake = FakeTrainingRepository(
      templates: [
        WorkoutTemplateSummary(
          id: 1,
          name: 'Chest',
          exerciseNames: const ['Bench Press'],
          updatedAt: DateTime(2026, 1, 2),
        ),
      ],
    )..templateWatchError = StateError('storage unavailable');
    addTearDown(fake.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [trainingRepositoryProvider.overrideWithValue(fake)],
        child: MaterialApp(
          home: TrainingScreen(
            onCreateTemplate: () {},
            onCreateRoutine: () {},
            onOpenTemplate: (_) {},
            onOpenRoutine: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('storage unavailable'), findsOneWidget);
    fake.templateWatchError = null;
    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Chest'), findsOneWidget);
  });

  testWidgets('Templates sort by recent update and show card preview', (
    tester,
  ) async {
    await pumpTraining(tester);
    await tester.pump();

    expect(
      tester.getTopLeft(find.text('Chest')).dy,
      lessThan(tester.getTopLeft(find.text('Legs')).dy),
    );
    expect(find.text('2 exercises'), findsOneWidget);
    expect(find.text('Bench Press • Cable Fly'), findsOneWidget);
    expect(find.bySemanticsLabel('Chest, 2 exercises'), findsOneWidget);
  });

  testWidgets('Routine cards open and search contained Template names', (
    tester,
  ) async {
    var openedId = 0;
    await pumpTraining(
      tester,
      onOpenRoutine: (id) => openedId = id,
      routines: [
        RoutineSummary(
          id: 7,
          name: 'PPL',
          templateNames: const ['Push', 'Pull', 'Legs'],
          updatedAt: DateTime(2026, 1, 3),
        ),
        RoutineSummary(
          id: 8,
          name: 'Upper Lower',
          templateNames: const ['Upper', 'Lower'],
          updatedAt: DateTime(2026, 1, 2),
        ),
      ],
    );
    await tester.tap(find.text('Routines'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Search Training'));
    await tester.enterText(find.byType(TextField), 'push');
    await tester.pump();

    expect(find.text('PPL'), findsOneWidget);
    expect(find.text('Upper Lower'), findsNothing);
    expect(find.text('3 Templates'), findsOneWidget);
    expect(find.text('Push • Pull • Legs'), findsOneWidget);
    expect(find.bySemanticsLabel('PPL, 3 Templates'), findsOneWidget);
    await tester.tap(find.text('PPL'));
    expect(openedId, 7);
  });

  testWidgets('selected overflow opens matching archive', (tester) async {
    await pumpTraining(tester, routines: const []);
    await tester.tap(find.text('Routines'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More Training actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archived Routines'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Archived Routines'), findsOneWidget);
  });

  testWidgets('archived Template restores only after confirmation', (
    tester,
  ) async {
    final fake = FakeTrainingRepository(
      templates: [
        WorkoutTemplateSummary(
          id: 1,
          name: 'Chest',
          exerciseNames: const ['Bench Press'],
          updatedAt: DateTime(2026, 1, 2),
        ),
      ],
    );
    await fake.setTemplateArchived(1, archived: true);
    addTearDown(fake.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [trainingRepositoryProvider.overrideWithValue(fake)],
        child: MaterialApp(
          home: ArchivedTrainingScreen(
            contentType: TrainingContentType.templates,
            onOpenTemplate: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byTooltip('Restore Template'));
    await tester.pumpAndSettle();
    expect(fake.restoredTemplateIds, isEmpty);
    await tester.tap(find.widgetWithText(FilledButton, 'Restore'));
    await tester.pump();
    await tester.pump();

    expect(fake.restoredTemplateIds, [1]);
    expect(find.text('Chest'), findsNothing);
  });

  testWidgets('screen exposes no Calendar or Active Routine state', (
    tester,
  ) async {
    await pumpTraining(tester);
    await tester.pump();

    expect(find.textContaining('Calendar'), findsNothing);
    expect(find.textContaining('Active Routine'), findsNothing);
    expect(find.textContaining('Schedule'), findsNothing);
  });

  testWidgets('controllers dispose cleanly after search and tab changes', (
    tester,
  ) async {
    await pumpTraining(tester);
    await tester.tap(find.text('Routines'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Search Training'));
    await tester.enterText(find.byType(TextField), 'push');
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
