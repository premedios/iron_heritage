import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iron_heritage/src/core/navigation/app_shell.dart';
import 'package:iron_heritage/src/features/training/domain/training_models.dart';
import 'package:iron_heritage/src/features/training/presentation/routine/routine_detail_screen.dart';
import 'package:iron_heritage/src/features/training/presentation/routine/routine_editor_screen.dart';
import 'package:iron_heritage/src/features/training/presentation/template/template_detail_screen.dart';
import 'package:iron_heritage/src/features/training/presentation/template/template_editor_screen.dart';
import 'package:iron_heritage/src/features/training/presentation/training_destination.dart';
import 'package:iron_heritage/src/features/training/presentation/training_providers.dart';
import 'package:iron_heritage/src/features/training/presentation/training_screen.dart';

import '../../support/fake_training_repository.dart';

Finder navDestination(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

List<RoutineSummary> routineSummaries(int count) => List.generate(
  count,
  (index) => RoutineSummary(
    id: index + 1,
    name: 'Routine ${index + 1}',
    templateNames: const ['Push'],
    updatedAt: DateTime(2026, 1, 1),
  ),
);

Widget shellWith(Widget training) => MaterialApp(
  home: AppShell(
    initialIndex: 1,
    home: const Center(child: Text('Home unavailable')),
    training: training,
    calendar: const Center(child: Text('Calendar unavailable')),
  ),
);

Future<void> pumpDestination(
  WidgetTester tester,
  FakeTrainingRepository repository,
) async {
  addTearDown(repository.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [trainingRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: TrainingDestination()),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('shell exposes exact destinations and preserves child state', (
    tester,
  ) async {
    await tester.pumpWidget(
      shellWith(const Material(child: TextField(key: Key('trainingQuery')))),
    );

    final navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(
      navigation.destinations.cast<NavigationDestination>().map(
        (destination) => destination.label,
      ),
      ['Home', 'Training', 'Calendar'],
    );
    expect(navigation.selectedIndex, 1);

    await tester.enterText(find.byKey(const Key('trainingQuery')), 'bench');
    await tester.tap(navDestination('Calendar'));
    await tester.pumpAndSettle();
    await tester.tap(navDestination('Training'));
    await tester.pumpAndSettle();

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.controller.text, 'bench');
  });

  testWidgets('shell preserves Training tab query and scroll offset', (
    tester,
  ) async {
    final repository = FakeTrainingRepository(routines: routineSummaries(30));
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [trainingRepositoryProvider.overrideWithValue(repository)],
        child: shellWith(
          TrainingScreen(
            onCreateTemplate: () {},
            onCreateRoutine: () {},
            onOpenTemplate: (_) {},
            onOpenRoutine: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Routines'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Search Training'));
    await tester.enterText(find.byType(TextField), 'routine');
    await tester.pump();

    final list = find.byKey(
      const PageStorageKey<String>('training-routine-list'),
    );
    final scrollable = find.descendant(
      of: list,
      matching: find.byType(Scrollable),
    );
    await tester.drag(list, const Offset(0, -500));
    await tester.pumpAndSettle();
    final before = tester.state<ScrollableState>(scrollable).position.pixels;
    expect(before, greaterThan(0));

    await tester.tap(navDestination('Calendar'));
    await tester.pumpAndSettle();
    await tester.tap(navDestination('Training'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Create Routine'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'routine',
    );
    expect(tester.state<ScrollableState>(scrollable).position.pixels, before);
  });

  testWidgets(
    'Training coordinator creates with one repository and save pops',
    (tester) async {
      final repository = FakeTrainingRepository();
      await pumpDestination(tester, repository);

      await tester.tap(find.byTooltip('Create Template'));
      await tester.pumpAndSettle();
      final templateEditor = tester.widget<TemplateEditorScreen>(
        find.byType(TemplateEditorScreen),
      );
      expect(templateEditor.repository, same(repository));
      templateEditor.onSaved!(101);
      await tester.pumpAndSettle();
      expect(find.byType(TrainingScreen), findsOneWidget);

      await tester.tap(find.text('Routines'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Create Routine'));
      await tester.pumpAndSettle();
      final routineEditor = tester.widget<RoutineEditorScreen>(
        find.byType(RoutineEditorScreen),
      );
      expect(routineEditor.repository, same(repository));
      routineEditor.onSaved(102);
      await tester.pumpAndSettle();
      expect(find.byType(TrainingScreen), findsOneWidget);
    },
  );

  testWidgets(
    'Training coordinator opens Template flows and reports unavailable workout',
    (tester) async {
      final repository = FakeTrainingRepository(
        templates: [
          WorkoutTemplateSummary(
            id: 1,
            name: 'Chest',
            exerciseNames: const [],
            updatedAt: DateTime(2026, 1, 1),
          ),
        ],
      );
      repository.templateDraftsById[1] = WorkoutTemplateDraft(
        id: 1,
        name: 'Chest',
        prescriptions: const [],
      );
      await pumpDestination(tester, repository);

      await tester.tap(find.text('Chest'));
      await tester.pumpAndSettle();
      final detail = tester.widget<TemplateDetailScreen>(
        find.byType(TemplateDetailScreen),
      );
      expect(detail.repository, same(repository));

      await tester.tap(find.text('Start Workout'));
      await tester.pump();
      expect(
        find.text('Workout tracking is not available yet'),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Edit Template'));
      await tester.pumpAndSettle();
      final editor = tester.widget<TemplateEditorScreen>(
        find.byType(TemplateEditorScreen),
      );
      expect(editor.repository, same(repository));
      repository.templateDraftsById[1] = WorkoutTemplateDraft(
        id: 1,
        name: 'Upper',
        prescriptions: const [],
      );
      editor.onSaved!(1);
      await tester.pumpAndSettle();
      expect(find.byType(TemplateDetailScreen), findsOneWidget);
      expect(find.text('Upper'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(TrainingScreen), findsOneWidget);
    },
  );

  testWidgets(
    'Training coordinator opens Routine flows and preserves back navigation',
    (tester) async {
      final repository = FakeTrainingRepository(
        routines: [
          RoutineSummary(
            id: 7,
            name: 'PPL',
            templateNames: const [],
            updatedAt: DateTime(2026, 1, 1),
          ),
        ],
      );
      final ownedTemplate = WorkoutTemplateDraft(
        id: 8,
        routineId: 7,
        name: 'Push',
        prescriptions: const [],
      );
      repository
        ..routineDraftsById[7] = RoutineDraft(
          id: 7,
          name: 'PPL',
          templates: [ownedTemplate],
        )
        ..templateDraftsById[8] = ownedTemplate;
      await pumpDestination(tester, repository);

      await tester.tap(find.text('Routines'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PPL'));
      await tester.pumpAndSettle();
      final detail = tester.widget<RoutineDetailScreen>(
        find.byType(RoutineDetailScreen),
      );
      expect(detail.repository, same(repository));

      await tester.tap(find.text('Push'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Workout'));
      await tester.pump();
      expect(
        find.text('Workout tracking is not available yet'),
        findsOneWidget,
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit Routine'));
      await tester.pumpAndSettle();
      final editor = tester.widget<RoutineEditorScreen>(
        find.byType(RoutineEditorScreen),
      );
      expect(editor.repository, same(repository));
      repository.routineDraftsById[7] = RoutineDraft(
        id: 7,
        name: 'Upper Lower',
        templates: [ownedTemplate],
      );
      editor.onSaved(7);
      await tester.pumpAndSettle();
      expect(find.byType(RoutineDetailScreen), findsOneWidget);
      expect(find.text('Upper Lower'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(TrainingScreen), findsOneWidget);
      expect(find.byTooltip('Create Routine'), findsOneWidget);
    },
  );
}
