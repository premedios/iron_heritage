import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iron_heritage/src/features/training/data/training_repository.dart';
import 'package:iron_heritage/src/features/training/domain/training_models.dart';
import 'package:iron_heritage/src/features/training/presentation/template/template_detail_screen.dart';

WorkoutTemplateDraft template({
  int id = 7,
  String name = 'Upper',
  bool archived = false,
}) {
  return WorkoutTemplateDraft(
    id: id,
    name: name,
    archivedAt: archived ? DateTime(2026, 7, 23) : null,
    prescriptions: [
      ExercisePrescriptionDraft(
        exerciseId: 11,
        exerciseName: 'Bench Press',
        notes: 'Pause on chest',
        plannedSets: const [
          PlannedSetDraft(weight: 100, minReps: 8, maxReps: 10, rir: 2),
          PlannedSetDraft(minReps: 12, type: PlannedSetType.dropset),
        ],
      ),
      ExercisePrescriptionDraft(
        exerciseId: 12,
        exerciseName: 'Cable Fly',
        plannedSets: const [PlannedSetDraft()],
      ),
    ],
  );
}

Future<_DetailRepository> _pumpDetail(
  WidgetTester tester, {
  WorkoutTemplateDraft? value,
  VoidCallback? onStartWorkout,
  ValueChanged<WorkoutTemplateDraft>? onEdit,
  VoidCallback? onArchived,
  _DetailRepository? repository,
}) async {
  final repo = repository ?? _DetailRepository(value ?? template());
  await tester.pumpWidget(
    MaterialApp(
      home: TemplateDetailScreen(
        templateId: 7,
        repository: repo,
        onStartWorkout: onStartWorkout ?? () {},
        onEdit: onEdit ?? (_) {},
        onArchived: onArchived ?? () {},
      ),
    ),
  );
  await tester.pump();
  return repo;
}

void main() {
  testWidgets('renders ordered Exercises, Planned Sets, notes, and types', (
    tester,
  ) async {
    await _pumpDetail(tester);

    expect(find.widgetWithText(AppBar, 'Upper'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Bench Press')).dy,
      lessThan(tester.getTopLeft(find.text('Cable Fly')).dy),
    );
    expect(find.text('Pause on chest'), findsOneWidget);
    expect(find.text('Set 1'), findsNWidgets(2));
    expect(find.text('Set 2'), findsOneWidget);
    expect(find.text('Weight: 100'), findsOneWidget);
    expect(find.text('Reps: 8–10'), findsOneWidget);
    expect(find.text('RIR: 2'), findsOneWidget);
    expect(find.text('Working'), findsNWidgets(2));
    expect(find.text('Dropset'), findsOneWidget);
    expect(find.textContaining('Calendar'), findsNothing);
    expect(find.textContaining('Scheduled'), findsNothing);
    expect(find.textContaining('Status'), findsNothing);
  });

  testWidgets('Start Workout and Edit invoke their callbacks exactly once', (
    tester,
  ) async {
    var starts = 0;
    WorkoutTemplateDraft? edited;
    final value = template();
    await _pumpDetail(
      tester,
      value: value,
      onStartWorkout: () => starts++,
      onEdit: (value) => edited = value,
    );

    await tester.tap(find.text('Start Workout'));
    await tester.tap(find.byTooltip('Edit Template'));

    expect(starts, 1);
    expect(edited, same(value));
    expect(edited?.id, 7);
  });

  testWidgets('Archive requires confirmation and reports navigation once', (
    tester,
  ) async {
    var navigations = 0;
    final repository = await _pumpDetail(
      tester,
      onArchived: () => navigations++,
    );

    await tester.tap(find.byTooltip('More Template actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();

    expect(find.text('Archive Template?'), findsOneWidget);
    expect(repository.archiveCalls, isEmpty);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.archiveCalls, isEmpty);

    await tester.tap(find.byTooltip('More Template actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
    await tester.pumpAndSettle();

    expect(repository.archiveCalls, [(id: 7, archived: true)]);
    expect(navigations, 1);
  });

  testWidgets('archived detail keeps Edit and confirms Restore', (
    tester,
  ) async {
    WorkoutTemplateDraft? edited;
    final repository = await _pumpDetail(
      tester,
      value: template(archived: true),
      onEdit: (value) => edited = value,
    );

    expect(find.text('Start Workout'), findsNothing);
    expect(find.byTooltip('Edit Template'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit Template'));
    expect(edited?.id, 7);
    await tester.tap(find.byTooltip('More Template actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();

    expect(find.text('Restore Template?'), findsOneWidget);
    expect(repository.archiveCalls, isEmpty);
    await tester.tap(find.widgetWithText(FilledButton, 'Restore'));
    await tester.pumpAndSettle();

    expect(repository.archiveCalls, [(id: 7, archived: false)]);
    expect(find.text('Start Workout'), findsOneWidget);
    expect(find.byTooltip('Edit Template'), findsOneWidget);
  });

  testWidgets('archive failure retains detail and allows retry', (
    tester,
  ) async {
    final repository = _DetailRepository(template())
      ..archiveError = StateError('disk unavailable');
    await _pumpDetail(tester, repository: repository);

    await tester.tap(find.byTooltip('More Template actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
    await tester.pumpAndSettle();

    expect(find.text('Upper'), findsWidgets);
    expect(find.text('Bench Press'), findsOneWidget);
    expect(
      find.textContaining(
        'Could not archive Template: Bad state: disk unavailable',
      ),
      findsOneWidget,
    );
    repository.archiveError = null;
    await tester.tap(find.byTooltip('More Template actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
    await tester.pumpAndSettle();

    expect(repository.archiveCalls, hasLength(2));
  });

  testWidgets('duplicate Restore error stays archived and can retry once', (
    tester,
  ) async {
    final repository = _DetailRepository(template(archived: true))
      ..archiveError = const DuplicateTrainingName(
        'name',
        'An active Template already uses this name',
      );
    await _pumpDetail(tester, repository: repository);

    await tester.tap(find.byTooltip('More Template actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Restore'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('An active Template already uses this name'),
      findsOneWidget,
    );
    expect(find.text('Start Workout'), findsNothing);
    repository.archiveError = null;
    await tester.tap(find.byTooltip('More Template actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Restore'));
    await tester.pumpAndSettle();

    expect(repository.archiveCalls, [
      (id: 7, archived: false),
      (id: 7, archived: false),
    ]);
    expect(find.text('Start Workout'), findsOneWidget);
  });

  testWidgets('load error gives a Retry that refreshes the detail', (
    tester,
  ) async {
    final repository = _DetailRepository(template())
      ..loadError = StateError('database closed');
    await _pumpDetail(tester, repository: repository);

    expect(
      find.textContaining(
        'Could not load Template: Bad state: database closed',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
    repository.loadError = null;
    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pump();
    await tester.pump();

    expect(repository.loadCalls, 2);
    expect(find.text('Bench Press'), findsOneWidget);
  });

  testWidgets('pending local load uses a spinner-free detail skeleton', (
    tester,
  ) async {
    final repository = _DetailRepository(template())..delayLoad = true;
    await _pumpDetail(tester, repository: repository);

    expect(find.byKey(const Key('template-detail-skeleton')), findsOneWidget);
    expect(find.bySemanticsLabel('Loading Template'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
    'pending archive retains content and disables duplicate actions',
    (tester) async {
      final repository = _DetailRepository(template())..delayArchive = true;
      var navigations = 0;
      await _pumpDetail(
        tester,
        repository: repository,
        onArchived: () => navigations++,
      );

      await tester.tap(find.byTooltip('More Template actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Bench Press'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Archiving Template',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<PopupMenuButton>(
              find.byWidgetPredicate((widget) => widget is PopupMenuButton),
            )
            .enabled,
        isFalse,
      );
      expect(repository.archiveCalls, [(id: 7, archived: true)]);
      repository.completeArchive();
      await tester.pumpAndSettle();

      expect(navigations, 1);
    },
  );

  testWidgets('late load after navigation is ignored', (tester) async {
    final repository = _DetailRepository(template())..delayLoad = true;
    await _pumpDetail(tester, repository: repository);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    repository.completeLoad(0);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('stale load cannot replace a newly navigated Template', (
    tester,
  ) async {
    final repository = _DetailRepository(template())..delayLoad = true;
    var templateId = 7;
    StateSetter? refresh;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            refresh = setState;
            return TemplateDetailScreen(
              templateId: templateId,
              repository: repository,
              onStartWorkout: () {},
              onEdit: (_) {},
              onArchived: () {},
            );
          },
        ),
      ),
    );
    await tester.pump();
    templateId = 8;
    refresh!(() {});
    await tester.pump();
    expect(repository.loadCalls, 2);

    repository.completeLoad(1, template(id: 8, name: 'Lower'));
    repository.completeLoad(0, template(id: 7, name: 'Upper'));
    await tester.pumpAndSettle();

    expect(find.text('Lower'), findsOneWidget);
    expect(find.text('Upper'), findsNothing);
  });

  testWidgets(
    'identity change while confirmation is open cannot archive new Template',
    (tester) async {
      final firstRepository = _DetailRepository(template());
      final secondRepository = _DetailRepository(
        template(id: 8, name: 'Lower'),
      );
      var templateId = 7;
      TrainingRepository repository = firstRepository;
      var firstCallbacks = 0;
      var secondCallbacks = 0;
      VoidCallback onArchived = () => firstCallbacks++;
      StateSetter? refresh;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              refresh = setState;
              return TemplateDetailScreen(
                templateId: templateId,
                repository: repository,
                onStartWorkout: () {},
                onEdit: (_) {},
                onArchived: onArchived,
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byTooltip('More Template actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();

      templateId = 8;
      repository = secondRepository;
      onArchived = () => secondCallbacks++;
      refresh!(() {});
      await tester.pump();
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
      await tester.pumpAndSettle();

      expect(firstRepository.archiveCalls, isEmpty);
      expect(secondRepository.archiveCalls, isEmpty);
      expect(firstCallbacks, 0);
      expect(secondCallbacks, 0);
      expect(find.text('Lower'), findsOneWidget);
      expect(find.text('Upper'), findsNothing);
    },
  );

  testWidgets('identity change during write preserves newly loaded detail', (
    tester,
  ) async {
    final firstRepository = _DetailRepository(template())..delayArchive = true;
    final secondRepository = _DetailRepository(template(id: 8, name: 'Lower'));
    var templateId = 7;
    TrainingRepository repository = firstRepository;
    var firstCallbacks = 0;
    var secondCallbacks = 0;
    VoidCallback onArchived = () => firstCallbacks++;
    StateSetter? refresh;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            refresh = setState;
            return TemplateDetailScreen(
              templateId: templateId,
              repository: repository,
              onStartWorkout: () {},
              onEdit: (_) {},
              onArchived: onArchived,
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('More Template actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
    await tester.pump(const Duration(seconds: 1));
    expect(firstRepository.archiveCalls, [(id: 7, archived: true)]);

    templateId = 8;
    repository = secondRepository;
    onArchived = () => secondCallbacks++;
    refresh!(() {});
    await tester.pump();
    await tester.pump();
    expect(find.text('Lower'), findsOneWidget);
    expect(secondRepository.archiveCalls, isEmpty);

    firstRepository.completeArchive();
    await tester.pumpAndSettle();

    expect(firstRepository.archiveCalls, [(id: 7, archived: true)]);
    expect(secondRepository.archiveCalls, isEmpty);
    expect(firstCallbacks, 0);
    expect(secondCallbacks, 0);
    expect(find.text('Lower'), findsOneWidget);
    expect(find.text('Upper'), findsNothing);
  });

  testWidgets('actions and ordered cards expose accessible semantics', (
    tester,
  ) async {
    await _pumpDetail(tester);

    expect(
      find.bySemanticsLabel('Exercise 1 of 2, Bench Press, 2 Planned Sets'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Exercise 2 of 2, Cable Fly, 1 Planned Set'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Start Workout'), findsOneWidget);
    expect(find.bySemanticsLabel('Edit Template'), findsOneWidget);
    expect(
      tester.getSize(find.byTooltip('Edit Template')).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byTooltip('More Template actions')).height,
      greaterThanOrEqualTo(48),
    );
  });
}

final class _DetailRepository implements TrainingRepository {
  _DetailRepository(this.value);

  WorkoutTemplateDraft value;
  Object? loadError;
  Object? archiveError;
  bool delayLoad = false;
  bool delayArchive = false;
  int loadCalls = 0;
  final archiveCalls = <({int id, bool archived})>[];
  final _loadCompleters = <Completer<WorkoutTemplateDraft?>>[];
  Completer<void>? _archiveCompleter;

  void completeLoad(int index, [WorkoutTemplateDraft? loaded]) =>
      _loadCompleters[index].complete(loaded ?? value);
  void completeArchive() => _archiveCompleter!.complete();

  @override
  Future<WorkoutTemplateDraft?> loadTemplate(int id) {
    loadCalls++;
    final error = loadError;
    if (error != null) {
      return Future.error(error);
    }
    if (delayLoad) {
      final completer = Completer<WorkoutTemplateDraft?>();
      _loadCompleters.add(completer);
      return completer.future;
    }
    return Future.value(value);
  }

  @override
  Future<void> setTemplateArchived(int id, {required bool archived}) {
    archiveCalls.add((id: id, archived: archived));
    final error = archiveError;
    if (error != null) {
      return Future.error(error);
    }
    if (delayArchive) {
      _archiveCompleter = Completer<void>();
      return _archiveCompleter!.future;
    }
    return Future.value();
  }

  @override
  Future<ExercisePrescriptionDraft?> latestPrescription(int exerciseId) =>
      throw UnimplementedError();

  @override
  Future<RoutineDraft?> loadRoutine(int id) => throw UnimplementedError();

  @override
  Future<int> saveRoutine(RoutineDraft draft) => throw UnimplementedError();

  @override
  Future<int> saveRoutineTemplateAsStandalone(int templateId) =>
      throw UnimplementedError();

  @override
  Future<int> saveTemplate(WorkoutTemplateDraft draft) =>
      throw UnimplementedError();

  @override
  Future<void> setRoutineArchived(int id, {required bool archived}) =>
      throw UnimplementedError();

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
