import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iron_heritage/src/features/training/data/training_repository.dart';
import 'package:iron_heritage/src/features/training/domain/training_models.dart';
import 'package:iron_heritage/src/features/training/presentation/routine/routine_detail_screen.dart';
import 'package:iron_heritage/src/features/training/presentation/template/template_detail_screen.dart';
import 'package:iron_heritage/src/features/training/presentation/template/template_editor_screen.dart';

WorkoutTemplateDraft _template({
  required int id,
  required String name,
  required int exerciseId,
  required String exerciseName,
}) {
  return WorkoutTemplateDraft(
    id: id,
    routineId: 4,
    name: name,
    prescriptions: [
      ExercisePrescriptionDraft(
        id: id * 10,
        exerciseId: exerciseId,
        exerciseName: exerciseName,
        plannedSets: [PlannedSetDraft(id: id * 100)],
      ),
    ],
  );
}

RoutineDraft _routine({
  int id = 4,
  String name = 'Strength',
  DateTime? archivedAt,
}) {
  return RoutineDraft(
    id: id,
    archivedAt: archivedAt,
    name: name,
    templates: [
      _template(
        id: 41,
        name: 'Upper',
        exerciseId: 1,
        exerciseName: 'Bench Press',
      ),
      _template(
        id: 42,
        name: 'Lower',
        exerciseId: 2,
        exerciseName: 'Back Squat',
      ),
    ],
  );
}

Future<_RoutineDetailRepository> _pumpDetail(
  WidgetTester tester, {
  _RoutineDetailRepository? repository,
  ValueChanged<int>? onStartWorkout,
  ValueChanged<RoutineDraft>? onEdit,
}) async {
  final repo = repository ?? _RoutineDetailRepository(_routine());
  await tester.pumpWidget(
    MaterialApp(
      home: RoutineDetailScreen(
        routineId: 4,
        repository: repo,
        onStartWorkout: onStartWorkout ?? (_) {},
        onEdit: onEdit ?? (_) {},
      ),
    ),
  );
  await tester.pump();
  return repo;
}

Future<void> _openUpper(WidgetTester tester) async {
  await tester.tap(find.text('Upper'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders ordered owned Templates without progression state', (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      repository: _RoutineDetailRepository(
        _routine(archivedAt: DateTime(2042, 9, 17)),
      ),
    );

    expect(find.widgetWithText(AppBar, 'Strength'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Upper')).dy,
      lessThan(tester.getTopLeft(find.text('Lower')).dy),
    );
    expect(find.text('1 exercise'), findsNWidgets(2));
    expect(find.textContaining('Start Routine'), findsNothing);
    expect(find.textContaining('Active Routine'), findsNothing);
    expect(find.textContaining('Calendar'), findsNothing);
    expect(find.textContaining('Scheduled'), findsNothing);
    expect(find.textContaining('2042'), findsNothing);
    expect(find.textContaining('September'), findsNothing);
  });

  testWidgets('Routine Edit receives the loaded aggregate', (tester) async {
    RoutineDraft? edited;
    final value = _routine();
    await _pumpDetail(
      tester,
      repository: _RoutineDetailRepository(value),
      onEdit: (routine) => edited = routine,
    );

    await tester.tap(find.byTooltip('Edit Routine'));

    expect(edited, same(value));
    expect(edited?.templates.map((item) => item.id), [41, 42]);
  });

  testWidgets('tapping owned Template opens its read-first detail', (
    tester,
  ) async {
    await _pumpDetail(tester);
    await _openUpper(tester);

    expect(find.byType(TemplateDetailScreen), findsOneWidget);
    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Start Workout'), findsOneWidget);
    expect(find.text('Save copy to Templates'), findsOneWidget);
    expect(find.byTooltip('More Template actions'), findsNothing);
    expect(find.text('Archive'), findsNothing);
    expect(find.text('Restore'), findsNothing);
  });

  testWidgets('owned detail starts the selected Template exactly once', (
    tester,
  ) async {
    final started = <int>[];
    await _pumpDetail(tester, onStartWorkout: started.add);
    await _openUpper(tester);

    await tester.tap(find.text('Start Workout'));

    expect(started, [41]);
  });

  testWidgets('owned Edit saves only that persisted Routine copy', (
    tester,
  ) async {
    final repository = await _pumpDetail(tester);
    final originalLower = repository.templates[42];
    await _openUpper(tester);

    await tester.tap(find.byTooltip('Edit Template'));
    await tester.pumpAndSettle();
    expect(find.byType(TemplateEditorScreen), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Upper'),
      'Upper changed',
    );
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(repository.savedTemplates, hasLength(1));
    expect(repository.savedTemplates.single.id, 41);
    expect(repository.savedTemplates.single.routineId, 4);
    expect(repository.templates[42], same(originalLower));
    expect(find.byType(TemplateEditorScreen), findsNothing);
    expect(find.byType(TemplateDetailScreen), findsOneWidget);
    expect(find.text('Upper changed'), findsWidgets);
  });

  testWidgets('Save copy calls owned ID and reports copied name', (
    tester,
  ) async {
    final repository = await _pumpDetail(tester);
    final owned = repository.templates[41]!;
    await _openUpper(tester);

    await tester.tap(find.text('Save copy to Templates'));
    await tester.pumpAndSettle();

    expect(repository.copyCalls, [41]);
    expect(repository.templates[41], same(owned));
    expect(repository.standaloneCopies, hasLength(1));
    final copy = repository.standaloneCopies.single;
    expect(copy, isNot(same(owned)));
    expect(copy.id, isNull);
    expect(copy.routineId, isNull);
    expect(copy.prescriptions.single.id, isNull);
    expect(copy.prescriptions.single.plannedSets.single.id, isNull);
    expect(copy.prescriptions, isNot(same(owned.prescriptions)));
    expect(
      copy.prescriptions.single.plannedSets,
      isNot(same(owned.prescriptions.single.plannedSets)),
    );
    expect(find.textContaining('Upper saved to Templates'), findsOneWidget);
  });

  testWidgets('duplicate copy failure is inline and preserves owned Template', (
    tester,
  ) async {
    final repository = _RoutineDetailRepository(_routine())
      ..copyError = const DuplicateTrainingName(
        'name',
        'A Template with this name already exists',
      );
    final owned = repository.templates[41]!;
    await _pumpDetail(tester, repository: repository);
    await _openUpper(tester);

    await tester.tap(find.text('Save copy to Templates'));
    await tester.pumpAndSettle();

    expect(repository.copyCalls, [41]);
    expect(repository.templates[41], same(owned));
    expect(repository.standaloneCopies, isEmpty);
    expect(
      find.text('A Template with this name already exists'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('A Template with this name already exists'),
      findsOneWidget,
    );
    expect(find.text('Bench Press'), findsOneWidget);
  });

  testWidgets('copy is single-flight while repository write is pending', (
    tester,
  ) async {
    final repository = _RoutineDetailRepository(_routine())..delayCopy = true;
    await _pumpDetail(tester, repository: repository);
    await _openUpper(tester);

    await tester.tap(find.text('Save copy to Templates'));
    await tester.pump();
    final copyButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Save copy to Templates'),
    );
    expect(copyButton.onPressed, isNull);
    expect(repository.copyCalls, [41]);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Saving Template copy'), findsOneWidget);
    repository.completeCopy();
    await tester.pumpAndSettle();

    expect(repository.copyCalls, [41]);
  });

  testWidgets('Archive and Restore preserve all owned Templates', (
    tester,
  ) async {
    final repository = await _pumpDetail(tester);
    final upper = repository.templates[41];
    final lower = repository.templates[42];

    await tester.tap(find.byTooltip('More Routine actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
    await tester.pumpAndSettle();

    expect(repository.archiveCalls, [(id: 4, archived: true)]);
    expect(repository.templates[41], same(upper));
    expect(repository.templates[42], same(lower));

    await _pumpDetail(tester, repository: repository);
    await tester.tap(find.byTooltip('More Routine actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Restore'));
    await tester.pumpAndSettle();

    expect(repository.archiveCalls, [
      (id: 4, archived: true),
      (id: 4, archived: false),
    ]);
    expect(repository.templates[41], same(upper));
    expect(repository.templates[42], same(lower));
  });

  testWidgets('Archive requires confirmation and failure retains detail', (
    tester,
  ) async {
    final repository = _RoutineDetailRepository(_routine())
      ..archiveError = StateError('disk unavailable');
    await _pumpDetail(tester, repository: repository);

    await tester.tap(find.byTooltip('More Routine actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    expect(repository.archiveCalls, isEmpty);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.archiveCalls, isEmpty);

    await tester.tap(find.byTooltip('More Routine actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
    await tester.pumpAndSettle();

    expect(repository.archiveCalls, [(id: 4, archived: true)]);
    expect(find.text('Upper'), findsOneWidget);
    expect(
      find.textContaining(
        'Could not archive Routine: Bad state: disk unavailable',
      ),
      findsOneWidget,
    );
  });

  testWidgets('load error retries and pending load uses accessible skeleton', (
    tester,
  ) async {
    final repository = _RoutineDetailRepository(_routine())
      ..loadError = StateError('database closed');
    await _pumpDetail(tester, repository: repository);

    expect(
      find.textContaining('Could not load Routine: Bad state: database closed'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Could not load Routine: Bad state: database closed',
      ),
      findsOneWidget,
    );
    repository.loadError = null;
    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pump();
    await tester.pump();

    expect(repository.loadRoutineCalls, 2);
    expect(find.text('Upper'), findsOneWidget);

    repository
      ..delayRoutineLoad = true
      ..routineLoadCompleters.clear();
    await tester.pumpWidget(
      MaterialApp(
        home: RoutineDetailScreen(
          routineId: 5,
          repository: repository,
          onStartWorkout: (_) {},
          onEdit: (_) {},
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('routine-detail-skeleton')), findsOneWidget);
    expect(find.bySemanticsLabel('Loading Routine'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('cached Routine refresh failure stays visible with Retry', (
    tester,
  ) async {
    final repository = await _pumpDetail(tester);
    await _openUpper(tester);
    repository.loadError = StateError('refresh unavailable');

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Upper'), findsOneWidget);
    expect(
      find.textContaining(
        'Could not refresh Routine: Bad state: refresh unavailable',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Could not refresh Routine: Bad state: refresh unavailable',
      ),
      findsOneWidget,
    );
    final retrySemantics = tester.getSemantics(find.bySemanticsLabel('Retry'));
    expect(
      retrySemantics.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );
    repository.loadError = null;
    await tester.tap(find.widgetWithText(OutlinedButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not refresh Routine:'), findsNothing);
    expect(find.text('Lower'), findsOneWidget);
  });

  testWidgets('owned Template refresh failure is visible and retryable', (
    tester,
  ) async {
    final repository = await _pumpDetail(tester);
    await _openUpper(tester);
    await tester.tap(find.byTooltip('Edit Template'));
    await tester.pumpAndSettle();
    repository.templateLoadError = StateError('template refresh unavailable');

    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Bench Press'), findsOneWidget);
    expect(
      find.textContaining(
        'Could not refresh Template: Bad state: template refresh unavailable',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Could not refresh Template: Bad state: template refresh unavailable',
      ),
      findsOneWidget,
    );
    repository.templateLoadError = null;
    await tester.tap(find.widgetWithText(OutlinedButton, 'Retry refresh'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not refresh Template:'), findsNothing);
    expect(find.byType(TemplateDetailScreen), findsOneWidget);
  });

  testWidgets('owned refresh serializes editing and renders newest result', (
    tester,
  ) async {
    final repository = await _pumpDetail(tester);
    await _openUpper(tester);
    await tester.tap(find.byTooltip('Edit Template'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Upper'),
      'Newest Upper',
    );
    repository.delayTemplateLoad = true;

    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(repository.templateLoadCompleters, hasLength(1));
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byIcon(Icons.edit_outlined),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Save copy to Templates'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byTooltip('Edit Template'), warnIfMissed: false);
    await tester.pump();
    expect(find.byType(TemplateEditorScreen), findsNothing);

    repository.delayTemplateLoad = false;
    repository.completeTemplateLoad(0, repository.templates[41]!);
    await tester.pumpAndSettle();

    expect(repository.templateLoadCompleters, hasLength(1));
    expect(find.text('Newest Upper'), findsWidgets);
    expect(find.byType(TemplateEditorScreen), findsNothing);
  });

  testWidgets('null owned refresh shows not-found and disables stale actions', (
    tester,
  ) async {
    final repository = await _pumpDetail(tester);
    await _openUpper(tester);
    await tester.tap(find.byTooltip('Edit Template'));
    await tester.pumpAndSettle();
    repository.templateLoadReturnsNull = true;

    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not refresh Template: Template not found'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Could not refresh Template: Template not found'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byIcon(Icons.edit_outlined),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Save copy to Templates'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Start Workout'),
          )
          .onPressed,
      isNull,
    );

    repository.templateLoadReturnsNull = false;
    await tester.tap(find.widgetWithText(OutlinedButton, 'Retry refresh'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not refresh Template:'), findsNothing);
    expect(find.text('Start Workout'), findsOneWidget);
  });

  testWidgets('stale Routine load cannot replace a newly selected identity', (
    tester,
  ) async {
    final repository = _RoutineDetailRepository(_routine())
      ..delayRoutineLoad = true;
    var routineId = 4;
    StateSetter? refresh;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            refresh = setState;
            return RoutineDetailScreen(
              routineId: routineId,
              repository: repository,
              onStartWorkout: (_) {},
              onEdit: (_) {},
            );
          },
        ),
      ),
    );
    await tester.pump();
    routineId = 5;
    refresh!(() {});
    await tester.pump();

    repository.completeRoutineLoad(1, _routine(id: 5, name: 'New Routine'));
    repository.completeRoutineLoad(0, _routine(name: 'Old Routine'));
    await tester.pumpAndSettle();

    expect(find.text('New Routine'), findsOneWidget);
    expect(find.text('Old Routine'), findsNothing);
  });

  testWidgets('identity change while archive dialog is open writes neither', (
    tester,
  ) async {
    final first = _RoutineDetailRepository(_routine());
    final second = _RoutineDetailRepository(
      _routine(id: 5, name: 'New Routine'),
    );
    var routineId = 4;
    TrainingRepository repository = first;
    StateSetter? refresh;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            refresh = setState;
            return RoutineDetailScreen(
              routineId: routineId,
              repository: repository,
              onStartWorkout: (_) {},
              onEdit: (_) {},
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('More Routine actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();

    routineId = 5;
    repository = second;
    refresh!(() {});
    await tester.pump();
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
    await tester.pumpAndSettle();

    expect(first.archiveCalls, isEmpty);
    expect(second.archiveCalls, isEmpty);
    expect(find.text('New Routine'), findsOneWidget);
  });

  testWidgets('owned route uses latest callback after parent rebuild', (
    tester,
  ) async {
    final repository = _RoutineDetailRepository(_routine());
    var firstCallbacks = 0;
    var secondCallbacks = 0;
    ValueChanged<int> onStartWorkout = (_) => firstCallbacks++;
    StateSetter? refresh;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            refresh = setState;
            return RoutineDetailScreen(
              routineId: 4,
              repository: repository,
              onStartWorkout: onStartWorkout,
              onEdit: (_) {},
            );
          },
        ),
      ),
    );
    await tester.pump();
    await _openUpper(tester);

    onStartWorkout = (_) => secondCallbacks++;
    refresh!(() {});
    await tester.pump();
    await tester.tap(find.text('Start Workout'));

    expect(firstCallbacks, 0);
    expect(secondCallbacks, 1);
  });

  testWidgets('parent identity change dismisses owned detail and editor', (
    tester,
  ) async {
    final first = _RoutineDetailRepository(_routine());
    final second = _RoutineDetailRepository(
      _routine(id: 5, name: 'New Routine'),
    );
    var routineId = 4;
    TrainingRepository repository = first;
    StateSetter? refresh;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            refresh = setState;
            return RoutineDetailScreen(
              routineId: routineId,
              repository: repository,
              onStartWorkout: (_) {},
              onEdit: (_) {},
            );
          },
        ),
      ),
    );
    await tester.pump();
    await _openUpper(tester);
    await tester.tap(find.byTooltip('Edit Template'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Upper'),
      'Unsaved change',
    );

    routineId = 5;
    repository = second;
    refresh!(() {});
    await tester.pumpAndSettle();

    expect(find.byType(TemplateEditorScreen), findsNothing);
    expect(find.byType(TemplateDetailScreen), findsNothing);
    expect(find.text('New Routine'), findsOneWidget);
    expect(first.savedTemplates, isEmpty);
    expect(second.savedTemplates, isEmpty);
  });

  testWidgets('identity change ignores delayed owned copy completion', (
    tester,
  ) async {
    final first = _RoutineDetailRepository(_routine())..delayCopy = true;
    final second = _RoutineDetailRepository(
      _routine(id: 5, name: 'New Routine'),
    );
    var routineId = 4;
    TrainingRepository repository = first;
    StateSetter? refresh;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            refresh = setState;
            return RoutineDetailScreen(
              routineId: routineId,
              repository: repository,
              onStartWorkout: (_) {},
              onEdit: (_) {},
            );
          },
        ),
      ),
    );
    await tester.pump();
    await _openUpper(tester);
    await tester.tap(find.text('Save copy to Templates'));
    await tester.pump();

    routineId = 5;
    repository = second;
    refresh!(() {});
    await tester.pumpAndSettle();
    first.completeCopy();
    await tester.pumpAndSettle();

    expect(first.copyCalls, [41]);
    expect(second.copyCalls, isEmpty);
    expect(find.textContaining('saved to Templates'), findsNothing);
    expect(find.byType(TemplateDetailScreen), findsNothing);
    expect(find.text('New Routine'), findsOneWidget);
  });

  testWidgets('identity change ignores delayed owned refresh completion', (
    tester,
  ) async {
    final first = _RoutineDetailRepository(_routine());
    final second = _RoutineDetailRepository(
      _routine(id: 5, name: 'New Routine'),
    );
    var routineId = 4;
    TrainingRepository repository = first;
    StateSetter? refresh;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            refresh = setState;
            return RoutineDetailScreen(
              routineId: routineId,
              repository: repository,
              onStartWorkout: (_) {},
              onEdit: (_) {},
            );
          },
        ),
      ),
    );
    await tester.pump();
    await _openUpper(tester);
    await tester.tap(find.byTooltip('Edit Template'));
    await tester.pumpAndSettle();
    first.delayTemplateLoad = true;
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pump();
    expect(first.templateLoadCompleters, hasLength(1));

    routineId = 5;
    repository = second;
    refresh!(() {});
    await tester.pumpAndSettle();
    first.completeTemplateLoad(0, first.templates[41]!);
    await tester.pumpAndSettle();

    expect(find.byType(TemplateDetailScreen), findsNothing);
    expect(find.text('New Routine'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cards and actions expose accessible labels and targets', (
    tester,
  ) async {
    await _pumpDetail(tester);

    expect(
      find.bySemanticsLabel('Template 1 of 2, Upper, 1 exercise'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Template 2 of 2, Lower, 1 exercise'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Edit Routine'), findsOneWidget);
    expect(
      tester.getSize(find.byTooltip('Edit Routine')).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byTooltip('More Routine actions')).height,
      greaterThanOrEqualTo(48),
    );
  });
}

final class _RoutineDetailRepository implements TrainingRepository {
  _RoutineDetailRepository(RoutineDraft routine) : routine = routine {
    for (final template in routine.templates) {
      templates[template.id!] = template;
    }
  }

  RoutineDraft routine;
  final templates = <int, WorkoutTemplateDraft>{};
  final savedTemplates = <WorkoutTemplateDraft>[];
  final standaloneCopies = <WorkoutTemplateDraft>[];
  final copyCalls = <int>[];
  final archiveCalls = <({int id, bool archived})>[];
  final routineLoadCompleters = <Completer<RoutineDraft?>>[];
  final templateLoadCompleters = <Completer<WorkoutTemplateDraft?>>[];
  Object? loadError;
  Object? templateLoadError;
  Object? copyError;
  Object? archiveError;
  bool delayRoutineLoad = false;
  bool delayTemplateLoad = false;
  bool templateLoadReturnsNull = false;
  bool delayCopy = false;
  int loadRoutineCalls = 0;
  Completer<int>? _copyCompleter;

  void completeRoutineLoad(int index, RoutineDraft value) {
    routineLoadCompleters[index].complete(value);
  }

  void completeCopy() => _copyCompleter!.complete(1000);

  void completeTemplateLoad(int index, WorkoutTemplateDraft value) {
    templateLoadCompleters[index].complete(value);
  }

  @override
  Future<RoutineDraft?> loadRoutine(int id) {
    loadRoutineCalls++;
    final error = loadError;
    if (error != null) {
      return Future.error(error);
    }
    if (delayRoutineLoad) {
      final completer = Completer<RoutineDraft?>();
      routineLoadCompleters.add(completer);
      return completer.future;
    }
    return Future.value(routine.id == id ? routine : null);
  }

  @override
  Future<WorkoutTemplateDraft?> loadTemplate(int id) {
    final error = templateLoadError;
    if (error != null) {
      return Future.error(error);
    }
    if (delayTemplateLoad) {
      final completer = Completer<WorkoutTemplateDraft?>();
      templateLoadCompleters.add(completer);
      return completer.future;
    }
    if (templateLoadReturnsNull) {
      return Future.value();
    }
    return Future.value(templates[id]);
  }

  @override
  Future<int> saveTemplate(WorkoutTemplateDraft draft) async {
    savedTemplates.add(draft);
    templates[draft.id!] = draft;
    routine = RoutineDraft(
      id: routine.id,
      archivedAt: routine.archivedAt,
      name: routine.name,
      templates: [
        for (final template in routine.templates)
          if (template.id == draft.id) draft else template,
      ],
    );
    return draft.id!;
  }

  @override
  Future<int> saveRoutineTemplateAsStandalone(int templateId) {
    copyCalls.add(templateId);
    final error = copyError;
    if (error != null) {
      return Future.error(error);
    }
    if (delayCopy) {
      _copyCompleter = Completer<int>();
      return _copyCompleter!.future.then((id) {
        standaloneCopies.add(templates[templateId]!.deepCopy());
        return id;
      });
    }
    standaloneCopies.add(templates[templateId]!.deepCopy());
    return Future.value(1000);
  }

  @override
  Future<void> setRoutineArchived(int id, {required bool archived}) async {
    archiveCalls.add((id: id, archived: archived));
    final error = archiveError;
    if (error != null) {
      throw error;
    }
    routine = RoutineDraft(
      id: routine.id,
      archivedAt: archived ? DateTime(2026) : null,
      name: routine.name,
      templates: routine.templates,
    );
  }

  @override
  Future<ExercisePrescriptionDraft?> latestPrescription(int exerciseId) async =>
      null;

  @override
  Future<int> saveRoutine(RoutineDraft draft) => throw UnimplementedError();

  @override
  Future<void> setTemplateArchived(int id, {required bool archived}) async {}

  @override
  Stream<List<RoutineSummary>> watchRoutines({
    required bool archived,
    String query = '',
  }) => throw UnimplementedError();

  @override
  Stream<List<WorkoutTemplateSummary>> watchTemplates({
    required bool archived,
    String query = '',
  }) => throw UnimplementedError();
}
