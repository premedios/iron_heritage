import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iron_heritage/src/features/training/data/training_repository.dart';
import 'package:iron_heritage/src/features/training/domain/training_models.dart';
import 'package:iron_heritage/src/features/training/presentation/template/template_editor_screen.dart';
import 'package:iron_heritage/src/features/training/presentation/widgets/accessible_reorder_handle.dart';

import '../../../support/fake_training_repository.dart';

WorkoutTemplateDraft draft({
  String name = 'Upper',
  List<ExercisePrescriptionDraft>? prescriptions,
}) {
  return WorkoutTemplateDraft(
    name: name,
    prescriptions:
        prescriptions ??
        [
          ExercisePrescriptionDraft(
            exerciseId: 7,
            exerciseName: 'Bench Press',
            plannedSets: const [PlannedSetDraft()],
          ),
        ],
  );
}

Future<FakeTrainingRepository> pumpEditor(
  WidgetTester tester, {
  WorkoutTemplateDraft? initial,
  bool embedded = true,
  ValueChanged<WorkoutTemplateDraft>? onCompleted,
  ValueChanged<int>? onSaved,
  TrainingRepository? repository,
}) async {
  final fake = repository is FakeTrainingRepository
      ? repository
      : FakeTrainingRepository();
  if (repository == null) {
    addTearDown(fake.dispose);
  }
  final repo = repository ?? fake;
  await tester.pumpWidget(
    MaterialApp(
      home: embedded
          ? TemplateEditorScreen.embedded(
              initial: initial ?? draft(),
              repository: repo,
              onCompleted: onCompleted ?? (_) {},
            )
          : TemplateEditorScreen.persisted(
              initial: initial ?? draft(),
              repository: repo,
              onSaved: onSaved ?? (_) {},
            ),
    ),
  );
  return fake;
}

void invokeCustomAction(WidgetTester tester, Finder handle, String label) {
  final semantics = tester.widget<Semantics>(
    find.descendant(of: handle, matching: find.byType(Semantics)).first,
  );
  final action = semantics.properties.customSemanticsActions!.entries
      .singleWhere((entry) => entry.key.label == label);
  action.value();
}

void main() {
  testWidgets('renders name and inline Planned Set fields', (tester) async {
    await pumpEditor(tester);

    expect(find.widgetWithText(TextFormField, 'Template name'), findsOneWidget);
    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Weight'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Min reps'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Max reps'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'RIR'), findsOneWidget);
    expect(find.text('Working'), findsOneWidget);
    expect(find.text('Dropset'), findsOneWidget);
  });

  testWidgets('first set may save with every target blank', (tester) async {
    WorkoutTemplateDraft? completed;
    await pumpEditor(tester, onCompleted: (value) => completed = value);

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(completed, isNotNull);
    expect(completed!.prescriptions.single.plannedSets.single.weight, isNull);
    expect(completed!.prescriptions.single.plannedSets.single.minReps, isNull);
    expect(completed!.prescriptions.single.plannedSets.single.maxReps, isNull);
    expect(completed!.prescriptions.single.plannedSets.single.rir, isNull);
  });

  testWidgets('removing final Planned Set shows minimum error', (tester) async {
    await pumpEditor(tester);

    await tester.tap(find.byTooltip('Remove set 1 from Bench Press'));
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Add at least one set'), findsOneWidget);
  });

  testWidgets('drag reorder changes Exercise order', (tester) async {
    WorkoutTemplateDraft? completed;
    await pumpEditor(
      tester,
      initial: draft(
        prescriptions: [
          ExercisePrescriptionDraft(
            exerciseId: 7,
            exerciseName: 'Bench Press',
            plannedSets: const [PlannedSetDraft()],
          ),
          ExercisePrescriptionDraft(
            exerciseId: 9,
            exerciseName: 'Cable Fly',
            plannedSets: const [PlannedSetDraft()],
          ),
        ],
      ),
      onCompleted: (value) => completed = value,
    );

    await tester.drag(
      find.byKey(const ValueKey('exercise-drag-7')),
      const Offset(0, 900),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));

    expect(completed!.prescriptions.map((item) => item.exerciseName), [
      'Cable Fly',
      'Bench Press',
    ]);
  });

  testWidgets('semantic Move Bench Press down reorders Exercises', (
    tester,
  ) async {
    WorkoutTemplateDraft? completed;
    await pumpEditor(
      tester,
      initial: draft(
        prescriptions: [
          ExercisePrescriptionDraft(
            exerciseId: 7,
            exerciseName: 'Bench Press',
            plannedSets: const [PlannedSetDraft()],
          ),
          ExercisePrescriptionDraft(
            exerciseId: 9,
            exerciseName: 'Cable Fly',
            plannedSets: const [PlannedSetDraft()],
          ),
        ],
      ),
      onCompleted: (value) => completed = value,
    );

    invokeCustomAction(
      tester,
      find.byKey(const ValueKey('exercise-drag-7')),
      'Move Bench Press down',
    );
    await tester.pump();
    await tester.tap(find.text('Save'));

    expect(completed!.prescriptions.map((item) => item.exerciseName), [
      'Cable Fly',
      'Bench Press',
    ]);
  });

  testWidgets('Planned Sets reorder through drag and semantic actions', (
    tester,
  ) async {
    WorkoutTemplateDraft? completed;
    await pumpEditor(
      tester,
      initial: draft(
        prescriptions: [
          ExercisePrescriptionDraft(
            exerciseId: 7,
            exerciseName: 'Bench Press',
            plannedSets: const [
              PlannedSetDraft(minReps: 5),
              PlannedSetDraft(minReps: 8),
              PlannedSetDraft(minReps: 12),
            ],
          ),
        ],
      ),
      onCompleted: (value) => completed = value,
    );

    await tester.drag(
      find.byKey(const ValueKey('set-drag-7-0')),
      const Offset(0, 700),
    );
    await tester.pumpAndSettle();
    invokeCustomAction(
      tester,
      find.byKey(const ValueKey('set-drag-7-2')),
      'Move set 3 up',
    );
    await tester.pump();
    await tester.tap(find.text('Save'));

    expect(
      completed!.prescriptions.single.plannedSets.map((set) => set.minReps),
      [8, 5, 12],
    );
  });

  testWidgets('back with dirty state shows discard confirmation', (
    tester,
  ) async {
    final fake = FakeTrainingRepository();
    addTearDown(fake.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => TemplateEditorScreen.embedded(
                    initial: draft(),
                    repository: fake,
                    onCompleted: (_) {},
                  ),
                ),
              ),
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Template name'),
      'Changed',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
    expect(find.text('Keep editing'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);
  });

  testWidgets('failed Save focuses and announces the name error', (
    tester,
  ) async {
    await pumpEditor(tester, initial: draft(name: ''));

    await tester.tap(find.text('Save'));
    await tester.pump();

    final editable = tester.widget<EditableText>(
      find.descendant(
        of: find.widgetWithText(TextFormField, 'Template name'),
        matching: find.byType(EditableText),
      ),
    );
    expect(editable.focusNode.hasFocus, isTrue);
    expect(find.text('Enter a Template name'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.liveRegion == true &&
            widget.properties.label?.contains('Enter a Template name') == true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('persisted mode returns saved Template ID', (tester) async {
    int? savedId;
    await pumpEditor(
      tester,
      embedded: false,
      onSaved: (value) => savedId = value,
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedId, 1000);
  });

  testWidgets('back is blocked while a persisted save is in flight', (
    tester,
  ) async {
    final repository = _DelayedSaveRepository();
    addTearDown(repository.dispose);
    int? savedId;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => TemplateEditorScreen.persisted(
                    initial: draft(),
                    repository: repository,
                    onSaved: (id) => savedId = id,
                  ),
                ),
              ),
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Template name'),
      'Changed',
    );
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.bySemanticsLabel('Saving Template'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();

    expect(find.text('Edit Template'), findsNothing);
    expect(find.text('New Template'), findsOneWidget);
    expect(find.text('Discard changes?'), findsNothing);

    repository.completeFirstSave(42);
    await tester.pumpAndSettle();
    expect(savedId, 42);
  });

  testWidgets(
    'keyboard and stale semantic actions cannot mutate while saving',
    (tester) async {
      final repository = _DelayedSaveRepository();
      addTearDown(repository.dispose);
      await pumpEditor(
        tester,
        embedded: false,
        repository: repository,
        initial: draft(
          prescriptions: [
            ExercisePrescriptionDraft(
              exerciseId: 7,
              exerciseName: 'Bench Press',
              plannedSets: const [PlannedSetDraft()],
            ),
            ExercisePrescriptionDraft(
              exerciseId: 9,
              exerciseName: 'Cable Fly',
              plannedSets: const [PlannedSetDraft()],
            ),
          ],
        ),
      );
      final name = find.widgetWithText(TextFormField, 'Template name');
      await tester.tap(name);
      await tester.showKeyboard(name);
      final semantics = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byKey(const ValueKey('exercise-drag-7')),
              matching: find.byType(Semantics),
            )
            .first,
      );
      final staleMoveAction = semantics
          .properties
          .customSemanticsActions!
          .entries
          .singleWhere((entry) => entry.key.label == 'Move Bench Press down')
          .value;

      await tester.tap(find.text('Save'));
      await tester.pump();
      tester.testTextInput.enterText('Mutated while saving');
      staleMoveAction();
      await tester.pump();

      expect(tester.widget<TextFormField>(name).enabled, isFalse);
      expect(tester.widget<TextFormField>(name).controller!.text, 'Upper');
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Notes').first,
            )
            .enabled,
        isFalse,
      );
      expect(
        tester
            .widget<AccessibleReorderHandle>(
              find.byKey(
                const ValueKey('exercise-drag-7'),
                skipOffstage: false,
              ),
            )
            .enabled,
        isFalse,
      );

      repository.completeFirstSave(42);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.savedDrafts, hasLength(2));
      expect(repository.savedDrafts.last.name, 'Upper');
      expect(
        repository.savedDrafts.last.prescriptions.map(
          (prescription) => prescription.exerciseName,
        ),
        ['Bench Press', 'Cable Fly'],
      );
    },
  );

  testWidgets('invalid load and reps stay visible and prevent persistence', (
    tester,
  ) async {
    final fake = await pumpEditor(tester, embedded: false);

    await tester.enterText(find.widgetWithText(TextField, 'Weight'), 'heavy');
    await tester.enterText(find.widgetWithText(TextField, 'Min reps'), '8.5');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Weight'))
          .decoration!
          .errorText,
      'Enter a number',
    );
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Min reps'))
          .decoration!
          .errorText,
      'Enter a whole number',
    );
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Weight'))
          .controller!
          .text,
      'heavy',
    );
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Min reps'))
          .controller!
          .text,
      '8.5',
    );
    expect(fake.savedTemplates, isEmpty);
  });

  testWidgets('reorder handle exposes named custom semantic actions', (
    tester,
  ) async {
    await pumpEditor(
      tester,
      initial: draft(
        prescriptions: [
          ExercisePrescriptionDraft(
            exerciseId: 7,
            exerciseName: 'Bench Press',
            plannedSets: const [PlannedSetDraft(), PlannedSetDraft()],
          ),
        ],
      ),
    );

    final semantics = tester.widget<Semantics>(
      find
          .descendant(
            of: find.byKey(const ValueKey('set-drag-7-1')),
            matching: find.byType(Semantics),
          )
          .first,
    );
    final labels = semantics.properties.customSemanticsActions!.keys.map(
      (action) => action.label,
    );
    expect(labels, contains('Move set 2 up'));
    expect(
      tester.getSize(find.byKey(const ValueKey('set-drag-7-1'))),
      const Size(48, 48),
    );
  });
}

final class _DelayedSaveRepository implements TrainingRepository {
  final delegate = FakeTrainingRepository();
  final firstSave = Completer<int>();
  final savedDrafts = <WorkoutTemplateDraft>[];

  void completeFirstSave(int id) => firstSave.complete(id);

  Future<void> dispose() => delegate.dispose();

  @override
  Future<int> saveTemplate(WorkoutTemplateDraft draft) {
    savedDrafts.add(draft);
    return savedDrafts.length == 1
        ? firstSave.future
        : Future.value(draft.id ?? 43);
  }

  @override
  Future<ExercisePrescriptionDraft?> latestPrescription(int exerciseId) =>
      delegate.latestPrescription(exerciseId);

  @override
  Future<WorkoutTemplateDraft?> loadTemplate(int id) =>
      delegate.loadTemplate(id);

  @override
  Future<RoutineDraft?> loadRoutine(int id) => delegate.loadRoutine(id);

  @override
  Future<int> saveRoutine(RoutineDraft draft) => delegate.saveRoutine(draft);

  @override
  Future<int> saveRoutineTemplateAsStandalone(int templateId) =>
      delegate.saveRoutineTemplateAsStandalone(templateId);

  @override
  Future<void> setRoutineArchived(int id, {required bool archived}) =>
      delegate.setRoutineArchived(id, archived: archived);

  @override
  Future<void> setTemplateArchived(int id, {required bool archived}) =>
      delegate.setTemplateArchived(id, archived: archived);

  @override
  Stream<List<RoutineSummary>> watchRoutines({
    required bool archived,
    String query = '',
  }) => delegate.watchRoutines(archived: archived, query: query);

  @override
  Stream<List<WorkoutTemplateSummary>> watchTemplates({
    required bool archived,
    String query = '',
  }) => delegate.watchTemplates(archived: archived, query: query);
}
