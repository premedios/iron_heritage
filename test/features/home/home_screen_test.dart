import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iron_heritage/src/core/theme/app_theme.dart';
import 'package:iron_heritage/src/features/home/presentation/home_screen.dart';
import 'package:iron_heritage/src/features/home/presentation/home_view_state.dart';

void main() {
  testWidgets('scheduled workout exposes its focus and start action', (
    tester,
  ) async {
    final actions = <HomeAction>[];

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          state: const HomeViewState(
            hero: ScheduledWorkoutHomeHero(
              routineName: 'Push Pull Legs',
              templateName: 'Push',
              exerciseCount: 6,
              estimatedDuration: Duration(minutes: 75),
              targetMuscleGroups: ['Chest', 'Shoulders', 'Triceps'],
            ),
            lastWorkout: LastWorkoutSummary(
              name: 'Pull',
              duration: Duration(minutes: 68),
              volumeKilograms: 12480,
              improvementPercent: 4.2,
            ),
          ),
          today: DateTime(2026, 7, 22),
          onAction: actions.add,
        ),
      ),
    );

    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('JULY 22'), findsOneWidget);
    expect(find.text('PUSH PULL LEGS'), findsOneWidget);
    expect(find.text('Push'), findsOneWidget);
    expect(find.text('6 exercises'), findsOneWidget);
    expect(find.text('75 min'), findsOneWidget);
    expect(find.text('Chest • Shoulders • Triceps'), findsOneWidget);
    expect(find.text('Start Empty Workout'), findsOneWidget);
    expect(find.text('Barbell Bench Press'), findsNothing);

    await tester.tap(find.text('Start Workout'));

    expect(actions, [HomeAction.startScheduledWorkout]);
  });

  testWidgets('active workout exposes progress and resume action', (
    tester,
  ) async {
    final actions = <HomeAction>[];

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          state: const HomeViewState(
            hero: ActiveWorkoutHomeHero(
              workoutName: 'Push',
              elapsed: Duration(minutes: 32, seconds: 15),
              completedExercises: 4,
              totalExercises: 6,
            ),
          ),
          today: DateTime(2026, 7, 22),
          onAction: actions.add,
        ),
      ),
    );

    expect(find.text('Workout in progress'), findsOneWidget);
    expect(find.text('Push'), findsOneWidget);
    expect(find.text('32:15 elapsed'), findsOneWidget);
    expect(find.text('4 of 6 exercises'), findsOneWidget);
    expect(find.text('Start Workout'), findsNothing);

    await tester.tap(find.text('Resume Workout'));

    expect(actions, [HomeAction.resumeWorkout]);
  });

  testWidgets('missed workout prompts for an explicit resolution', (
    tester,
  ) async {
    final actions = <HomeAction>[];

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          state: HomeViewState(
            hero: MissedWorkoutHomeHero(
              routineName: 'Push Pull Legs',
              templateName: 'Pull',
              scheduledDate: DateTime(2026, 7, 21),
            ),
          ),
          today: DateTime(2026, 7, 22),
          onAction: actions.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Resolve missed workout'), findsOneWidget);
    expect(find.text('Start now'), findsOneWidget);
    expect(find.text('Reschedule'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    await tester.tap(find.text('Reschedule'));
    await tester.pumpAndSettle();

    expect(actions, [HomeAction.rescheduleMissedWorkout]);
  });

  testWidgets('rest day shows the next workout without guilt language', (
    tester,
  ) async {
    final actions = <HomeAction>[];

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          state: HomeViewState(
            hero: RestDayHomeHero(
              nextTemplateName: 'Legs',
              nextWorkoutDate: DateTime(2026, 7, 24),
            ),
          ),
          today: DateTime(2026, 7, 22),
          onAction: actions.add,
        ),
      ),
    );

    expect(find.text('Recovery day'), findsOneWidget);
    expect(find.text('Next: Legs'), findsOneWidget);
    expect(find.text('JULY 24'), findsOneWidget);
    expect(find.textContaining('missed'), findsNothing);

    await tester.tap(find.text('Start Early'));

    expect(actions, [HomeAction.startEarly]);
  });

  testWidgets('no routine offers setup without blocking an empty workout', (
    tester,
  ) async {
    final actions = <HomeAction>[];

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          state: const HomeViewState(hero: NoRoutineHomeHero()),
          today: DateTime(2026, 7, 22),
          onAction: actions.add,
        ),
      ),
    );

    expect(find.text('Build your routine'), findsOneWidget);
    expect(find.text('Create or Choose Routine'), findsOneWidget);
    expect(find.text('Start Empty Workout'), findsOneWidget);
    expect(
      find.text('Your first completed workout will appear here.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Create or Choose Routine'));

    expect(actions, [HomeAction.chooseRoutine]);
  });

  testWidgets('last workout summary exposes progress and opens details', (
    tester,
  ) async {
    final actions = <HomeAction>[];

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          state: const HomeViewState(
            hero: NoRoutineHomeHero(),
            lastWorkout: LastWorkoutSummary(
              name: 'Pull',
              duration: Duration(minutes: 68),
              volumeKilograms: 12480,
              improvementPercent: 4.2,
            ),
          ),
          today: DateTime(2026, 7, 22),
          onAction: actions.add,
        ),
      ),
    );

    expect(find.text('LAST WORKOUT'), findsOneWidget);
    expect(find.text('Pull'), findsOneWidget);
    expect(find.text('68 min'), findsOneWidget);
    expect(find.text('12,480 kg'), findsOneWidget);
    expect(find.text('+4.2% vs previous'), findsOneWidget);

    await tester.tap(find.text('Pull'));

    expect(actions, [HomeAction.openLastWorkout]);
  });

  testWidgets('loading state preserves the home layout with skeletons', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          state: const HomeViewState.loading(),
          today: DateTime(2026, 7, 22),
          onAction: (_) {},
        ),
      ),
    );

    expect(find.bySemanticsLabel('Loading Home'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Build your routine'), findsNothing);
  });

  testWidgets('recoverable failure retains content and exposes retry', (
    tester,
  ) async {
    final actions = <HomeAction>[];

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          state: const HomeViewState(
            hero: NoRoutineHomeHero(),
            errorMessage: 'Could not refresh Home',
          ),
          today: DateTime(2026, 7, 22),
          onAction: actions.add,
        ),
      ),
    );

    expect(find.text('Could not refresh Home'), findsOneWidget);
    expect(find.text('Build your routine'), findsOneWidget);

    await tester.tap(find.text('Retry'));

    expect(actions, [HomeAction.retry]);
  });

  testWidgets('home shell exposes primary navigation and settings', (
    tester,
  ) async {
    final actions = <HomeAction>[];

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          state: const HomeViewState(hero: NoRoutineHomeHero()),
          today: DateTime(2026, 7, 22),
          onAction: actions.add,
        ),
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Routines'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);

    await tester.tap(find.text('Calendar'));
    await tester.tap(find.byTooltip('Settings'));

    expect(actions, [HomeAction.openCalendar, HomeAction.openSettings]);
  });

  testWidgets('home actions meet the minimum touch target', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: HomeScreen(
          state: const HomeViewState(hero: NoRoutineHomeHero()),
          today: DateTime(2026, 7, 22),
          onAction: (_) {},
        ),
      ),
    );

    final primary = tester.getSize(
      find.widgetWithText(ElevatedButton, 'Create or Choose Routine'),
    );
    final secondary = tester.getSize(
      find.widgetWithText(TextButton, 'Start Empty Workout'),
    );

    expect(primary.height, greaterThanOrEqualTo(48));
    expect(secondary.height, greaterThanOrEqualTo(48));
  });

  testWidgets('active workout outranks every scheduled home state', (
    tester,
  ) async {
    final state = HomeViewState.resolve(
      activeWorkout: const ActiveWorkoutHomeHero(
        workoutName: 'Live Push',
        elapsed: Duration(minutes: 12),
        completedExercises: 1,
        totalExercises: 6,
      ),
      missedWorkout: MissedWorkoutHomeHero(
        routineName: 'Push Pull Legs',
        templateName: 'Missed Pull',
        scheduledDate: DateTime(2026, 7, 21),
      ),
      scheduledWorkout: const ScheduledWorkoutHomeHero(
        routineName: 'Push Pull Legs',
        templateName: 'Scheduled Legs',
        exerciseCount: 5,
        estimatedDuration: Duration(minutes: 60),
        targetMuscleGroups: ['Legs'],
      ),
      restDay: RestDayHomeHero(
        nextTemplateName: 'Rest Legs',
        nextWorkoutDate: DateTime(2026, 7, 24),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          state: state,
          today: DateTime(2026, 7, 22),
          onAction: (_) {},
        ),
      ),
    );

    expect(find.text('Live Push'), findsOneWidget);
    expect(find.text('Resume Workout'), findsOneWidget);
    expect(find.text('Missed Pull'), findsNothing);
    expect(find.text('Scheduled Legs'), findsNothing);
    expect(find.text('Rest Legs'), findsNothing);
  });

  testWidgets('dismissing a missed workout prompt changes nothing', (
    tester,
  ) async {
    final actions = <HomeAction>[];

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          state: HomeViewState(
            hero: MissedWorkoutHomeHero(
              routineName: 'Push Pull Legs',
              templateName: 'Pull',
              scheduledDate: DateTime(2026, 7, 21),
            ),
          ),
          today: DateTime(2026, 7, 22),
          onAction: actions.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    expect(actions, isEmpty);
    expect(find.text('Resolve missed workout'), findsNothing);
    expect(find.text('Review options'), findsOneWidget);
  });

  testWidgets('last workout omits unavailable comparison data', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          state: const HomeViewState(
            hero: NoRoutineHomeHero(),
            lastWorkout: LastWorkoutSummary(
              name: 'First Push',
              duration: Duration(minutes: 55),
              volumeKilograms: 8400,
            ),
          ),
          today: DateTime(2026, 7, 22),
          onAction: (_) {},
        ),
      ),
    );

    expect(find.text('8,400 kg'), findsOneWidget);
    expect(find.textContaining('vs previous'), findsNothing);
  });

  testWidgets('large text keeps the scheduled action reachable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: HomeScreen(
          state: const HomeViewState(
            hero: ScheduledWorkoutHomeHero(
              routineName: 'Push Pull Legs',
              templateName: 'Push',
              exerciseCount: 6,
              estimatedDuration: Duration(minutes: 75),
              targetMuscleGroups: ['Chest', 'Shoulders', 'Triceps'],
            ),
          ),
          today: DateTime(2026, 7, 22),
          onAction: (_) {},
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Start Workout'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Start Workout'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final testCase in const [
    (label: 'Start now', action: HomeAction.startMissedWorkout),
    (label: 'Skip', action: HomeAction.skipMissedWorkout),
  ]) {
    testWidgets('missed workout emits ${testCase.label} intent', (
      tester,
    ) async {
      final actions = <HomeAction>[];

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            state: HomeViewState(
              hero: MissedWorkoutHomeHero(
                routineName: 'Push Pull Legs',
                templateName: 'Pull',
                scheduledDate: DateTime(2026, 7, 21),
              ),
            ),
            today: DateTime(2026, 7, 22),
            onAction: actions.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(testCase.label));
      await tester.pumpAndSettle();

      expect(actions, [testCase.action]);
    });
  }

  testWidgets('home exposes useful semantics for context and progress', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          state: const HomeViewState(
            hero: ActiveWorkoutHomeHero(
              workoutName: 'Push',
              elapsed: Duration(minutes: 32),
              completedExercises: 4,
              totalExercises: 6,
            ),
            lastWorkout: LastWorkoutSummary(
              name: 'Pull',
              duration: Duration(minutes: 68),
              volumeKilograms: 12480,
              improvementPercent: 4.2,
            ),
          ),
          today: DateTime(2026, 7, 22),
          onAction: (_) {},
        ),
      ),
    );

    expect(find.bySemanticsLabel('Today, July 22'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Workout in progress: Push, 32 minutes, 4 of 6 exercises completed',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Last Workout: Pull, 68 minutes, 12,480 kilograms, '
        '4.2 percent improvement versus previous',
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Settings'), findsOneWidget);
    semantics.dispose();
  });
}
