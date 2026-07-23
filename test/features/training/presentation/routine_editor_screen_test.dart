import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iron_heritage/src/core/database/database.dart';
import 'package:iron_heritage/src/features/exercise/presentation/exercise_list_screen.dart';
import 'package:iron_heritage/src/features/training/data/training_repository.dart';
import 'package:iron_heritage/src/features/training/domain/training_models.dart';
import 'package:iron_heritage/src/features/training/presentation/routine/routine_editor_screen.dart';

import '../../../support/fake_training_repository.dart';

void main() {
  testWidgets('Template picker wait uses a semantic skeleton, not a spinner', (
    tester,
  ) async {
    final fake = await _pumpEditor(tester);
    fake.templateWatchPending = true;

    await tester.tap(find.text('Add template'));
    await tester.pump();

    expect(find.bySemanticsLabel('Loading Templates'), findsOneWidget);
    expect(find.byKey(const Key('template-picker-skeleton-0')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('Add template opens standalone Template picker sheet', (
    tester,
  ) async {
    final fake = await _pumpEditor(tester);

    await tester.tap(find.text('Add template'));
    await tester.pumpAndSettle();

    expect(find.text('Add Templates'), findsOneWidget);
    expect(find.text('Create new'), findsOneWidget);
    expect(fake.templateWatchSubscriptions, 1);
  });

  testWidgets('picker multi-selects and loads full standalone Templates', (
    tester,
  ) async {
    final chest = _template(id: 11, name: 'Chest', setId: 31);
    final legs = _template(id: 12, name: 'Legs', exerciseName: 'Squat');
    final fake = await _pumpEditor(
      tester,
      templates: [_summary(chest), _summary(legs)],
      drafts: {11: chest, 12: legs},
    );

    await tester.tap(find.text('Add template'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Legs'));
    await tester.tap(find.text('Chest'));
    await tester.pump();
    expect(find.text('Add 2 templates'), findsOneWidget);
    await tester.tap(find.text('Add 2 templates'));
    await tester.pumpAndSettle();

    expect(find.text('Legs'), findsOneWidget);
    expect(find.text('Chest'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Routine name'),
      'Upper Lower',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = fake.savedRoutines.single.templates;
    expect(saved.map((template) => template.name), ['Legs', 'Chest']);
    expect(saved[1].id, isNull);
    expect(saved[1].prescriptions.single.plannedSets.single.id, isNull);
    expect(saved[1], isNot(same(chest)));
  });

  testWidgets('picker refresh removes unavailable Template selections', (
    tester,
  ) async {
    final chest = _template(id: 11, name: 'Chest');
    final legs = _template(id: 12, name: 'Legs');
    final fake = await _pumpEditor(
      tester,
      templates: [_summary(chest), _summary(legs)],
      drafts: {11: chest, 12: legs},
    );

    await tester.tap(find.text('Add template'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chest'));
    await tester.tap(find.text('Legs'));
    await tester.pump();
    expect(find.text('Add 2 templates'), findsOneWidget);

    fake.emitTemplates([_summary(chest)]);
    await tester.pump();
    await tester.pump();

    expect(find.text('Add 1 template'), findsOneWidget);
    expect(find.text('Legs'), findsNothing);
  });

  testWidgets(
    'picker completion keeps selected order when catalog refreshes during load',
    (tester) async {
      final chest = _template(id: 11, name: 'Chest');
      final legs = _template(id: 12, name: 'Legs');
      final delegate = FakeTrainingRepository(
        templates: [_summary(chest), _summary(legs)],
      )..templateDraftsById.addAll({11: chest, 12: legs});
      final repository = _DelayedTemplateLoadRepository(
        delegate: delegate,
        delayedId: 11,
      );
      addTearDown(repository.dispose);
      await _pumpEditor(tester, repository: repository);

      await tester.tap(find.text('Add template'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chest'));
      await tester.tap(find.text('Legs'));
      await tester.pump();
      await tester.tap(find.text('Add 2 templates'));
      await tester.pump();

      delegate.emitTemplates([_summary(chest)]);
      await tester.pump();
      await tester.pump();
      repository.completeDelayed(chest);
      await tester.pumpAndSettle();

      expect(find.text('Add Templates'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Routine name'),
        'Upper Lower',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        delegate.savedRoutines.single.templates.map(
          (template) => template.name,
        ),
        ['Chest', 'Legs'],
      );
    },
  );

  testWidgets('picker ignores duplicate completion while loads are busy', (
    tester,
  ) async {
    final chest = _template(id: 11, name: 'Chest');
    final delegate = FakeTrainingRepository(templates: [_summary(chest)])
      ..templateDraftsById[11] = chest;
    final repository = _DelayedTemplateLoadRepository(
      delegate: delegate,
      delayedId: 11,
    );
    addTearDown(repository.dispose);
    await _pumpEditor(tester, repository: repository);

    await tester.tap(find.text('Add template'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chest'));
    await tester.pump();
    await tester.tap(find.text('Add 1 template'));
    await tester.tap(find.text('Add 1 template'));
    await tester.pump();

    expect(repository.loadCalls, [11]);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.liveRegion == true,
      ),
      findsOneWidget,
    );
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .semanticsLabel,
      'Loading selected Templates',
    );
    expect(find.text('Adding selected Templates'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    repository.completeDelayed(chest);
    await tester.pumpAndSettle();
    expect(find.text('Add Templates'), findsNothing);
  });

  testWidgets('Create new opens embedded Template editor without persistence', (
    tester,
  ) async {
    final fake = await _pumpEditor(tester);

    await tester.tap(find.text('Add template'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create new'));
    await tester.pumpAndSettle();

    expect(find.text('New Template'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Template name'), findsOneWidget);
    expect(fake.savedTemplates, isEmpty);
  });

  testWidgets('created Template returns Routine-only without saveTemplate', (
    tester,
  ) async {
    final fake = await _pumpEditor(tester);

    await tester.tap(find.text('Add template'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create new'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Template name'),
      'Routine Push',
    );
    await tester.tap(find.text('Add exercise'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bench Press'));
    await tester.pump();
    await tester.tap(find.text('Add 1 exercise'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Add Templates'), findsOneWidget);
    expect(find.text('Routine Push'), findsOneWidget);
    expect(find.text('Add 1 template'), findsOneWidget);
    await tester.tap(find.text('Add 1 template'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Routine name'),
      'PPL',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(fake.savedTemplates, isEmpty);
    final owned = fake.savedRoutines.single.templates.single;
    expect(owned.name, 'Routine Push');
    expect(owned.id, isNull);
    expect(owned.routineId, isNull);
  });

  testWidgets('Save requires a name and at least one Template', (tester) async {
    final fake = await _pumpEditor(tester);

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Enter a Routine name'), findsOneWidget);
    expect(find.text('Add at least one Template'), findsOneWidget);
    expect(fake.savedRoutines, isEmpty);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.liveRegion == true &&
            widget.properties.label?.contains('Enter a Routine name') == true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('semantic move action mirrors drag ordering', (tester) async {
    final fake = await _pumpEditor(
      tester,
      initial: RoutineDraft(
        name: 'PPL',
        templates: [
          _template(name: 'Push'),
          _template(name: 'Pull'),
          _template(name: 'Legs'),
        ],
      ),
    );

    _invokeCustomAction(
      tester,
      find.byKey(const ValueKey('template-drag-0')),
      'Move Push down',
    );
    await tester.pump();
    await tester.drag(
      find.byKey(const ValueKey('template-drag-2')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      fake.savedRoutines.single.templates.map((template) => template.name),
      ['Legs', 'Pull', 'Push'],
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('template-drag-0'))),
      const Size(48, 48),
    );
  });

  testWidgets('discard confirmation protects dirty Routine changes', (
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
                  builder: (_) => RoutineEditorScreen(
                    initial: RoutineDraft(name: '', templates: const []),
                    repository: fake,
                    onSaved: (_) {},
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
      find.widgetWithText(TextFormField, 'Routine name'),
      'Changed',
    );
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();

    expect(find.text('New Routine'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Routine name'),
          )
          .controller!
          .text,
      'Changed',
    );
  });

  testWidgets('save in flight disables mutations and blocks back', (
    tester,
  ) async {
    final repository = _DelayedRoutineRepository();
    addTearDown(repository.dispose);
    await _pumpEditor(
      tester,
      repository: repository,
      initial: RoutineDraft(
        name: 'PPL',
        templates: [
          _template(name: 'Push'),
          _template(name: 'Pull'),
        ],
      ),
    );
    final staleAction = tester
        .widget<Semantics>(
          find
              .descendant(
                of: find.byKey(const ValueKey('template-drag-0')),
                matching: find.byType(Semantics),
              )
              .first,
        )
        .properties
        .customSemanticsActions!
        .entries
        .singleWhere((entry) => entry.key.label == 'Move Push down')
        .value;

    await tester.tap(find.text('Save'));
    await tester.pump();
    staleAction();
    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.bySemanticsLabel('Saving Routine'), findsOneWidget);
    expect(find.text('Discard changes?'), findsNothing);
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Routine name'),
          )
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip('Remove Push'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );

    repository.saveResult.complete(42);
    await tester.pumpAndSettle();
  });

  testWidgets('Routine editor contains no Calendar or scheduling knowledge', (
    tester,
  ) async {
    await _pumpEditor(
      tester,
      initial: RoutineDraft(
        name: 'PPL',
        templates: [_template(name: 'Push')],
      ),
    );

    expect(find.textContaining('Calendar'), findsNothing);
    expect(find.textContaining('schedule', findRichText: true), findsNothing);
    expect(find.textContaining('Active Routine'), findsNothing);
  });
}

Future<FakeTrainingRepository> _pumpEditor(
  WidgetTester tester, {
  RoutineDraft? initial,
  List<WorkoutTemplateSummary> templates = const [],
  Map<int, WorkoutTemplateDraft> drafts = const {},
  TrainingRepository? repository,
}) async {
  final fake = repository is FakeTrainingRepository
      ? repository
      : FakeTrainingRepository(templates: templates);
  if (repository == null) {
    addTearDown(fake.dispose);
  }
  fake.templateDraftsById.addAll(drafts);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        exercisesProvider.overrideWith(
          (_) => Stream.value(const [Exercise(id: 7, name: 'Bench Press')]),
        ),
      ],
      child: MaterialApp(
        home: RoutineEditorScreen(
          initial: initial ?? RoutineDraft(name: '', templates: const []),
          repository: repository ?? fake,
          onSaved: (_) {},
        ),
      ),
    ),
  );
  return fake;
}

void _invokeCustomAction(WidgetTester tester, Finder handle, String label) {
  final semantics = tester.widget<Semantics>(
    find.descendant(of: handle, matching: find.byType(Semantics)).first,
  );
  semantics.properties.customSemanticsActions!.entries
      .singleWhere((entry) => entry.key.label == label)
      .value();
}

WorkoutTemplateDraft _template({
  int? id,
  required String name,
  String exerciseName = 'Bench Press',
  int? setId,
}) {
  return WorkoutTemplateDraft(
    id: id,
    name: name,
    prescriptions: [
      ExercisePrescriptionDraft(
        exerciseId: id ?? name.hashCode,
        exerciseName: exerciseName,
        plannedSets: [PlannedSetDraft(id: setId)],
      ),
    ],
  );
}

WorkoutTemplateSummary _summary(WorkoutTemplateDraft draft) {
  return WorkoutTemplateSummary(
    id: draft.id!,
    name: draft.name,
    exerciseNames: draft.prescriptions
        .map((prescription) => prescription.exerciseName)
        .toList(),
    updatedAt: DateTime.utc(2026, 7, draft.id!),
  );
}

final class _DelayedRoutineRepository implements TrainingRepository {
  final delegate = FakeTrainingRepository();
  final saveResult = Completer<int>();

  Future<void> dispose() => delegate.dispose();

  @override
  Future<int> saveRoutine(RoutineDraft draft) => saveResult.future;

  @override
  Future<ExercisePrescriptionDraft?> latestPrescription(int exerciseId) =>
      delegate.latestPrescription(exerciseId);

  @override
  Future<RoutineDraft?> loadRoutine(int id) => delegate.loadRoutine(id);

  @override
  Future<WorkoutTemplateDraft?> loadTemplate(int id) =>
      delegate.loadTemplate(id);

  @override
  Future<int> saveRoutineTemplateAsStandalone(int templateId) =>
      delegate.saveRoutineTemplateAsStandalone(templateId);

  @override
  Future<int> saveTemplate(WorkoutTemplateDraft draft) =>
      delegate.saveTemplate(draft);

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

final class _DelayedTemplateLoadRepository implements TrainingRepository {
  _DelayedTemplateLoadRepository({
    required this.delegate,
    required this.delayedId,
  });

  final FakeTrainingRepository delegate;
  final int delayedId;
  final _delayed = Completer<WorkoutTemplateDraft?>();
  final loadCalls = <int>[];

  void completeDelayed(WorkoutTemplateDraft? draft) => _delayed.complete(draft);

  Future<void> dispose() => delegate.dispose();

  @override
  Future<WorkoutTemplateDraft?> loadTemplate(int id) {
    loadCalls.add(id);
    return id == delayedId ? _delayed.future : delegate.loadTemplate(id);
  }

  @override
  Future<ExercisePrescriptionDraft?> latestPrescription(int exerciseId) =>
      delegate.latestPrescription(exerciseId);

  @override
  Future<RoutineDraft?> loadRoutine(int id) => delegate.loadRoutine(id);

  @override
  Future<int> saveRoutine(RoutineDraft draft) => delegate.saveRoutine(draft);

  @override
  Future<int> saveRoutineTemplateAsStandalone(int templateId) =>
      delegate.saveRoutineTemplateAsStandalone(templateId);

  @override
  Future<int> saveTemplate(WorkoutTemplateDraft draft) =>
      delegate.saveTemplate(draft);

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
