import 'package:flutter/foundation.dart';

import '../../data/training_repository.dart';
import '../../domain/training_models.dart';
import '../../domain/training_validation.dart';

final class RoutineEditorController extends ChangeNotifier {
  factory RoutineEditorController({
    required TrainingRepository repository,
    required RoutineDraft initial,
  }) {
    return RoutineEditorController._(repository, initial);
  }

  RoutineEditorController._(this._repository, this._draft);

  final TrainingRepository _repository;

  RoutineDraft _draft;
  Map<String, String> _errors = const {};
  bool _saving = false;
  bool _dirty = false;
  bool _disposed = false;
  int _revision = 0;

  RoutineDraft get draft => _draft;
  Map<String, String> get errors => _errors;
  bool get saving => _saving;
  bool get dirty => _dirty;

  void setName(String value) {
    if (_disposed || _draft.name == value) {
      return;
    }
    _replaceDraft(name: value);
  }

  void addExistingTemplates(List<WorkoutTemplateDraft> selected) {
    if (_disposed || selected.isEmpty) {
      return;
    }
    _replaceDraft(
      templates: [
        ..._draft.templates,
        ...selected.map((template) => template.deepCopy()),
      ],
    );
  }

  void addCreatedTemplate(WorkoutTemplateDraft created) {
    if (_disposed) {
      return;
    }
    _replaceDraft(templates: [..._draft.templates, created.deepCopy()]);
  }

  void removeTemplate(int index) {
    if (_disposed) {
      return;
    }
    final templates = _draft.templates.toList()..removeAt(index);
    _replaceDraft(templates: templates);
  }

  void reorderTemplates(int oldIndex, int newIndex) {
    if (_disposed) {
      return;
    }
    final adjustedIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    if (adjustedIndex == oldIndex) {
      return;
    }
    final templates = _draft.templates.toList();
    final moved = templates.removeAt(oldIndex);
    templates.insert(adjustedIndex, moved);
    _replaceDraft(templates: templates);
  }

  Future<int?> save() async {
    if (_disposed || _saving) {
      return null;
    }

    final validationErrors = TrainingValidation.routine(_draft);
    if (validationErrors.isNotEmpty) {
      _errors = Map.unmodifiable(validationErrors);
      _dirty = true;
      notifyListeners();
      return null;
    }

    final savingRevision = _revision;
    _saving = true;
    notifyListeners();
    try {
      final id = await _repository.saveRoutine(_draft);
      if (!_disposed && _revision == savingRevision) {
        _dirty = false;
      }
      return id;
    } on DuplicateTrainingName catch (error) {
      if (!_disposed && _revision == savingRevision) {
        _errors = Map.unmodifiable({error.field: error.message});
        _dirty = true;
      }
      return null;
    } on InvalidTrainingDraft catch (error) {
      if (!_disposed && _revision == savingRevision) {
        _errors = Map.unmodifiable(error.errors);
        _dirty = true;
      }
      return null;
    } catch (_) {
      if (!_disposed && _revision == savingRevision) {
        _dirty = true;
      }
      rethrow;
    } finally {
      if (!_disposed) {
        _saving = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _replaceDraft({String? name, List<WorkoutTemplateDraft>? templates}) {
    _draft = RoutineDraft(
      id: _draft.id,
      archivedAt: _draft.archivedAt,
      name: name ?? _draft.name,
      templates: templates ?? _draft.templates,
    );
    _errors = const {};
    _dirty = true;
    _revision++;
    notifyListeners();
  }
}
