import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:iron_heritage/src/features/training/data/training_repository.dart';
import 'package:iron_heritage/src/features/training/domain/training_models.dart';
import 'package:iron_heritage/src/features/training/presentation/routine/routine_editor_controller.dart';

import '../../../support/fake_training_repository.dart';

void main() {
  late FakeTrainingRepository fake;

  setUp(() {
    fake = FakeTrainingRepository();
  });

  tearDown(() => fake.dispose());

  test('selected standalone Templates append as independent deep copies', () {
    final source = _template(
      id: 11,
      name: 'Chest',
      prescriptionId: 21,
      setId: 31,
    );
    final controller = RoutineEditorController(
      repository: fake,
      initial: RoutineDraft(name: '', templates: const []),
    );

    controller.addExistingTemplates([source]);

    final copied = controller.draft.templates.single;
    expect(copied.name, 'Chest');
    expect(copied.id, isNull);
    expect(copied.routineId, isNull);
    expect(copied, isNot(same(source)));
    expect(copied.prescriptions.single.id, isNull);
    expect(
      copied.prescriptions.single,
      isNot(same(source.prescriptions.single)),
    );
    expect(copied.prescriptions.single.plannedSets.single.id, isNull);
    expect(
      copied.prescriptions.single.plannedSets.single,
      isNot(same(source.prescriptions.single.plannedSets.single)),
    );
    expect(controller.dirty, isTrue);
  });

  test('creating inside a Routine clears standalone identity', () {
    final created = _template(id: 12, name: 'Legs', routineId: 99);
    final controller = RoutineEditorController(
      repository: fake,
      initial: RoutineDraft(name: '', templates: const []),
    );

    controller.addCreatedTemplate(created);

    final copied = controller.draft.templates.single;
    expect(copied.id, isNull);
    expect(copied.routineId, isNull);
    expect(copied, isNot(same(created)));
  });

  test('duplicate Template names inside one Routine block save', () async {
    final controller = RoutineEditorController(
      repository: fake,
      initial: RoutineDraft(
        name: 'Push Pull',
        templates: [
          _template(name: 'Chest'),
          _template(name: ' chest '),
        ],
      ),
    );

    expect(await controller.save(), isNull);

    expect(fake.savedRoutines, isEmpty);
    expect(
      controller.errors['templates.1.name'],
      'Template names must be unique inside this Routine',
    );
    expect(controller.dirty, isTrue);
  });

  test('reorder persists ordered Template list', () async {
    final controller = RoutineEditorController(
      repository: fake,
      initial: RoutineDraft(
        name: 'PPL',
        templates: [
          _template(name: 'Push'),
          _template(name: 'Pull'),
          _template(name: 'Legs'),
        ],
      ),
    );

    controller.reorderTemplates(0, 3);
    expect(await controller.save(), 1000);

    expect(
      fake.savedRoutines.single.templates.map((template) => template.name),
      ['Pull', 'Legs', 'Push'],
    );
  });

  test('removal changes only the Routine draft', () {
    final sourceTemplates = [
      _template(id: 1, name: 'Push'),
      _template(id: 2, name: 'Pull'),
    ];
    final initial = RoutineDraft(name: 'Upper', templates: sourceTemplates);
    final controller = RoutineEditorController(
      repository: fake,
      initial: initial,
    );

    controller.removeTemplate(0);

    expect(controller.draft.templates.map((template) => template.name), [
      'Pull',
    ]);
    expect(initial.templates.map((template) => template.name), [
      'Push',
      'Pull',
    ]);
    expect(sourceTemplates, hasLength(2));
  });

  test('save failure retains all copied drafts and dirty state', () async {
    fake.routineSaveError = StateError('disk full');
    final sources = [
      _template(id: 1, name: 'Push', prescriptionId: 10, setId: 20),
      _template(id: 2, name: 'Pull', prescriptionId: 11, setId: 21),
    ];
    final controller = RoutineEditorController(
      repository: fake,
      initial: RoutineDraft(name: 'PPL', templates: const []),
    )..addExistingTemplates(sources);
    final before = controller.draft.templates;

    await expectLater(controller.save(), throwsStateError);

    expect(controller.draft.templates, same(before));
    expect(controller.draft.templates.map((template) => template.name), [
      'Push',
      'Pull',
    ]);
    expect(controller.dirty, isTrue);
    expect(controller.saving, isFalse);
  });

  test('typed repository failure maps errors without losing draft', () async {
    fake.routineSaveError = const DuplicateTrainingName(
      'name',
      'A Routine with this name already exists',
    );
    final initial = RoutineDraft(
      id: 7,
      name: 'PPL',
      templates: [_template(name: 'Push')],
    );
    final controller = RoutineEditorController(
      repository: fake,
      initial: initial,
    );

    expect(await controller.save(), isNull);

    expect(controller.draft, same(initial));
    expect(controller.errors['name'], contains('already exists'));
    expect(controller.dirty, isTrue);
  });

  test('save success cannot mark edits made in flight clean', () async {
    final delayed = _DelayedRoutineRepository(fake);
    final controller = RoutineEditorController(
      repository: delayed,
      initial: RoutineDraft(
        name: 'PPL',
        templates: [_template(name: 'Push')],
      ),
    );
    controller.setName('Submitted');

    final pendingSave = controller.save();
    controller.setName('Edited while saving');
    delayed.saveResult.complete(41);

    expect(await pendingSave, 41);
    expect(controller.draft.name, 'Edited while saving');
    expect(controller.dirty, isTrue);
    expect(controller.saving, isFalse);
  });
}

WorkoutTemplateDraft _template({
  int? id,
  int? routineId,
  required String name,
  int? prescriptionId,
  int? setId,
}) {
  return WorkoutTemplateDraft(
    id: id,
    routineId: routineId,
    name: name,
    prescriptions: [
      ExercisePrescriptionDraft(
        id: prescriptionId,
        exerciseId: 7,
        exerciseName: 'Bench Press',
        plannedSets: [PlannedSetDraft(id: setId)],
      ),
    ],
  );
}

final class _DelayedRoutineRepository implements TrainingRepository {
  _DelayedRoutineRepository(this.delegate);

  final FakeTrainingRepository delegate;
  final saveResult = Completer<int>();

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
