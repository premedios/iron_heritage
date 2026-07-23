import 'package:flutter/foundation.dart';

import '../../data/training_repository.dart';
import '../../domain/training_models.dart';
import '../../domain/training_validation.dart';

final class TemplateEditorController extends ChangeNotifier {
  factory TemplateEditorController({
    required TrainingRepository repository,
    required WorkoutTemplateDraft initial,
  }) {
    return TemplateEditorController._(repository, initial);
  }

  TemplateEditorController._(this._repository, this._draft);

  final TrainingRepository _repository;

  WorkoutTemplateDraft _draft;
  Map<String, String> _errors = const {};
  bool _saving = false;
  bool _dirty = false;

  WorkoutTemplateDraft get draft => _draft;
  Map<String, String> get errors => _errors;
  bool get saving => _saving;
  bool get dirty => _dirty;

  Future<void> addExercises(List<ExerciseChoice> choices) async {
    if (choices.isEmpty) {
      return;
    }

    final additions = <ExercisePrescriptionDraft>[];
    for (final choice in choices) {
      final latest = await _repository.latestPrescription(choice.id);
      additions.add(
        latest?.deepCopy() ??
            ExercisePrescriptionDraft(
              exerciseId: choice.id,
              exerciseName: choice.name,
              plannedSets: const [PlannedSetDraft()],
            ),
      );
    }

    _replaceDraft(prescriptions: [..._draft.prescriptions, ...additions]);
  }

  void setName(String value) {
    if (_draft.name == value) {
      return;
    }
    _replaceDraft(name: value);
  }

  void setNotes(int prescriptionIndex, String value) {
    final current = _draft.prescriptions[prescriptionIndex];
    if (current.notes == value) {
      return;
    }
    _replacePrescription(
      prescriptionIndex,
      ExercisePrescriptionDraft(
        id: current.id,
        exerciseId: current.exerciseId,
        exerciseName: current.exerciseName,
        notes: value,
        plannedSets: current.plannedSets,
      ),
    );
  }

  void addPlannedSet(int prescriptionIndex) {
    final current = _draft.prescriptions[prescriptionIndex];
    _replacePrescription(
      prescriptionIndex,
      ExercisePrescriptionDraft(
        id: current.id,
        exerciseId: current.exerciseId,
        exerciseName: current.exerciseName,
        notes: current.notes,
        plannedSets: [...current.plannedSets, const PlannedSetDraft()],
      ),
    );
  }

  void updatePlannedSet(
    int prescriptionIndex,
    int setIndex,
    PlannedSetDraft value,
  ) {
    final current = _draft.prescriptions[prescriptionIndex];
    if (_samePlannedSet(current.plannedSets[setIndex], value)) {
      return;
    }
    final plannedSets = current.plannedSets.toList();
    plannedSets[setIndex] = value;
    _replacePrescription(
      prescriptionIndex,
      ExercisePrescriptionDraft(
        id: current.id,
        exerciseId: current.exerciseId,
        exerciseName: current.exerciseName,
        notes: current.notes,
        plannedSets: plannedSets,
      ),
    );
  }

  void removePlannedSet(int prescriptionIndex, int setIndex) {
    final current = _draft.prescriptions[prescriptionIndex];
    final plannedSets = current.plannedSets.toList()..removeAt(setIndex);
    _replacePrescription(
      prescriptionIndex,
      ExercisePrescriptionDraft(
        id: current.id,
        exerciseId: current.exerciseId,
        exerciseName: current.exerciseName,
        notes: current.notes,
        plannedSets: plannedSets,
      ),
    );
  }

  void reorderPlannedSets(int prescriptionIndex, int oldIndex, int newIndex) {
    final current = _draft.prescriptions[prescriptionIndex];
    final adjustedIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    if (adjustedIndex == oldIndex) {
      return;
    }
    final plannedSets = current.plannedSets.toList();
    final moved = plannedSets.removeAt(oldIndex);
    plannedSets.insert(adjustedIndex, moved);
    _replacePrescription(
      prescriptionIndex,
      ExercisePrescriptionDraft(
        id: current.id,
        exerciseId: current.exerciseId,
        exerciseName: current.exerciseName,
        notes: current.notes,
        plannedSets: plannedSets,
      ),
    );
  }

  void reorderExercises(int oldIndex, int newIndex) {
    final adjustedIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    if (adjustedIndex == oldIndex) {
      return;
    }
    final prescriptions = _draft.prescriptions.toList();
    final moved = prescriptions.removeAt(oldIndex);
    prescriptions.insert(adjustedIndex, moved);
    _replaceDraft(prescriptions: prescriptions);
  }

  void removeExercise(int index) {
    final prescriptions = _draft.prescriptions.toList()..removeAt(index);
    _replaceDraft(prescriptions: prescriptions);
  }

  WorkoutTemplateDraft? completeDraft() {
    final validationErrors = TrainingValidation.template(_draft);
    if (validationErrors.isNotEmpty) {
      _errors = Map.unmodifiable(validationErrors);
      _dirty = true;
      notifyListeners();
      return null;
    }

    if (_errors.isNotEmpty) {
      _errors = const {};
      notifyListeners();
    }
    return _draft;
  }

  Future<int?> save() async {
    if (_saving) {
      return null;
    }

    final completed = completeDraft();
    if (completed == null) {
      return null;
    }

    _saving = true;
    notifyListeners();
    try {
      final id = await _repository.saveTemplate(completed);
      _dirty = false;
      return id;
    } on DuplicateTrainingName catch (error) {
      _errors = Map.unmodifiable({error.field: error.message});
      _dirty = true;
      return null;
    } on InvalidTrainingDraft catch (error) {
      _errors = Map.unmodifiable(error.errors);
      _dirty = true;
      return null;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  void _replacePrescription(
    int prescriptionIndex,
    ExercisePrescriptionDraft prescription,
  ) {
    final prescriptions = _draft.prescriptions.toList();
    prescriptions[prescriptionIndex] = prescription;
    _replaceDraft(prescriptions: prescriptions);
  }

  void _replaceDraft({
    String? name,
    List<ExercisePrescriptionDraft>? prescriptions,
  }) {
    _draft = WorkoutTemplateDraft(
      id: _draft.id,
      routineId: _draft.routineId,
      archivedAt: _draft.archivedAt,
      name: name ?? _draft.name,
      prescriptions: prescriptions ?? _draft.prescriptions,
    );
    _errors = const {};
    _dirty = true;
    notifyListeners();
  }

  static bool _samePlannedSet(PlannedSetDraft left, PlannedSetDraft right) {
    return left.id == right.id &&
        left.weight == right.weight &&
        left.minReps == right.minReps &&
        left.maxReps == right.maxReps &&
        left.rir == right.rir &&
        left.type == right.type;
  }
}
