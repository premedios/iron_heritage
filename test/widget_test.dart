import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iron_heritage/app.dart';
import 'package:iron_heritage/flavors.dart';
import 'package:iron_heritage/src/features/home/presentation/home_controller.dart';
import 'package:iron_heritage/src/features/home/presentation/home_screen.dart';
import 'package:iron_heritage/src/features/home/presentation/home_view_state.dart';
import 'package:iron_heritage/src/features/sync/data/wger_repository.dart';

void main() {
  F.appFlavor = Flavor.dev;

  testWidgets('App opens the Home tab after synchronization', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [isSyncedProvider.overrideWith((ref) async => true)],
        child: const App(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Dashboard Placeholder'), findsNothing);
  });

  testWidgets('App exposes injected Home state and action events', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isSyncedProvider.overrideWith((ref) async => true),
          homeViewStateProvider.overrideWithValue(
            const HomeViewState(
              hero: ScheduledWorkoutHomeHero(
                routineName: 'Push Pull Legs',
                templateName: 'Push',
                exerciseCount: 6,
                estimatedDuration: Duration(minutes: 75),
                targetMuscleGroups: ['Chest', 'Shoulders', 'Triceps'],
              ),
            ),
          ),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(HomeScreen));
    final container = ProviderScope.containerOf(context);

    await tester.tap(find.text('Start Workout'));

    expect(
      container.read(homeActionEventProvider)?.action,
      HomeAction.startScheduledWorkout,
    );
  });
}
