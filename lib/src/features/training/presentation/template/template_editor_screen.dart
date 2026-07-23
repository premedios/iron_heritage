import 'package:flutter/material.dart';

import '../../data/training_repository.dart';
import '../../domain/training_models.dart';
import '../widgets/accessible_reorder_handle.dart';
import 'exercise_picker_screen.dart';
import 'template_editor_controller.dart';

final class TemplateEditorScreen extends StatefulWidget {
  const TemplateEditorScreen.persisted({
    required this.initial,
    required this.repository,
    required this.onSaved,
    super.key,
  }) : onCompleted = null;

  const TemplateEditorScreen.embedded({
    required this.initial,
    required this.repository,
    required this.onCompleted,
    super.key,
  }) : onSaved = null;

  final WorkoutTemplateDraft initial;
  final TrainingRepository repository;
  final ValueChanged<int>? onSaved;
  final ValueChanged<WorkoutTemplateDraft>? onCompleted;

  @override
  State<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

final class _TemplateEditorScreenState extends State<TemplateEditorScreen> {
  late final TemplateEditorController _controller;
  late final TextEditingController _nameController;
  final _nameFocusNode = FocusNode();
  final _setTokens = <int, List<Object>>{};
  final _setTargetErrors = <Object, Map<_SetTarget, String>>{};
  final _setTargetRaw = <Object, Map<_SetTarget, String>>{};
  bool _allowPop = false;
  String? _announcement;

  @override
  void initState() {
    super.initState();
    _controller = TemplateEditorController(
      repository: widget.repository,
      initial: widget.initial,
    )..addListener(_onControllerChanged);
    _nameController = TextEditingController(text: widget.initial.name);
    _synchronizeTokens();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onControllerChanged)
      ..dispose();
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = _controller.draft;
    return PopScope<Object?>(
      canPop: !_controller.saving && (_allowPop || !_controller.dirty),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_controller.saving) {
          _confirmDiscard();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(draft.id == null ? 'New Template' : 'Edit Template'),
          actions: [
            TextButton(
              onPressed: _controller.saving ? null : _save,
              child: const Text('Save'),
            ),
          ],
          bottom: _controller.saving
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(3),
                  child: LinearProgressIndicator(
                    semanticsLabel: 'Saving Template',
                  ),
                )
              : null,
        ),
        body: AbsorbPointer(
          absorbing: _controller.saving,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              if (_announcement case final announcement?)
                Semantics(
                  container: true,
                  liveRegion: true,
                  label: announcement,
                  child: _ValidationMessage(announcement),
                ),
              TextFormField(
                controller: _nameController,
                focusNode: _nameFocusNode,
                enabled: !_controller.saving,
                decoration: InputDecoration(
                  labelText: 'Template name',
                  errorText: _controller.errors['name'],
                ),
                textInputAction: TextInputAction.next,
                onChanged: (value) {
                  if (!_controller.saving) {
                    _controller.setName(value);
                  }
                },
              ),
              const SizedBox(height: 16),
              if (_controller.errors['prescriptions'] case final error?)
                _ValidationMessage(error),
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: draft.prescriptions.length,
                onReorderItem: _reorderExercises,
                itemBuilder: (context, index) {
                  final prescription = draft.prescriptions[index];
                  return _ExerciseEditor(
                    key: ValueKey(
                      prescription.id == null
                          ? 'exercise-${prescription.exerciseId}'
                          : 'prescription-${prescription.id}',
                    ),
                    index: index,
                    prescription: prescription,
                    setTokens: _setTokens[prescription.exerciseId]!,
                    targetErrors: _setTargetErrors,
                    targetRaw: _setTargetRaw,
                    setError:
                        _controller.errors['prescriptions.$index.plannedSets'],
                    mutationsEnabled: !_controller.saving,
                    onNotesChanged: (value) => _setNotes(index, value),
                    onRemove: () {
                      if (_controller.saving) {
                        return;
                      }
                      for (final token
                          in _setTokens[prescription.exerciseId]!) {
                        _setTargetErrors.remove(token);
                        _setTargetRaw.remove(token);
                      }
                      _controller.removeExercise(index);
                      _synchronizeTokens();
                    },
                    onAddSet: () {
                      if (_controller.saving) {
                        return;
                      }
                      _controller.addPlannedSet(index);
                      _synchronizeTokens();
                    },
                    onRemoveSet: (setIndex) {
                      if (_controller.saving) {
                        return;
                      }
                      _setTargetErrors.remove(
                        _setTokens[prescription.exerciseId]![setIndex],
                      );
                      _setTargetRaw.remove(
                        _setTokens[prescription.exerciseId]![setIndex],
                      );
                      _setTokens[prescription.exerciseId]!.removeAt(setIndex);
                      _controller.removePlannedSet(index, setIndex);
                      _synchronizeTokens();
                    },
                    onUpdateSet: (setIndex, value) {
                      if (!_controller.saving) {
                        _controller.updatePlannedSet(index, setIndex, value);
                      }
                    },
                    onSetValidityChanged: _setTargetValidity,
                    onReorderSets: (oldIndex, newIndex) =>
                        _reorderSets(index, oldIndex, newIndex),
                    exerciseHandle: AccessibleReorderHandle(
                      key: ValueKey('exercise-drag-${prescription.exerciseId}'),
                      index: index,
                      label: prescription.exerciseName,
                      enabled: !_controller.saving,
                      onMoveUp: index == 0
                          ? null
                          : () => _reorderExercises(index, index - 1),
                      onMoveDown: index == draft.prescriptions.length - 1
                          ? null
                          : () => _reorderExercises(index, index + 1),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _controller.saving ? null : _addExercises,
                icon: const Icon(Icons.add),
                label: const Text('Add exercise'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onControllerChanged() {
    if (!mounted) {
      return;
    }
    _synchronizeTokens();
    setState(() {});
  }

  void _synchronizeTokens() {
    for (final prescription in _controller.draft.prescriptions) {
      final tokens = _setTokens.putIfAbsent(
        prescription.exerciseId,
        () => <Object>[],
      );
      while (tokens.length < prescription.plannedSets.length) {
        final set = prescription.plannedSets[tokens.length];
        tokens.add(set.id ?? Object());
      }
      if (tokens.length > prescription.plannedSets.length) {
        tokens.removeRange(prescription.plannedSets.length, tokens.length);
      }
    }
  }

  void _reorderExercises(int oldIndex, int newIndex) {
    if (_controller.saving) {
      return;
    }
    final controllerIndex = newIndex > oldIndex ? newIndex + 1 : newIndex;
    _controller.reorderExercises(oldIndex, controllerIndex);
  }

  void _reorderSets(int prescriptionIndex, int oldIndex, int newIndex) {
    if (_controller.saving) {
      return;
    }
    final prescription = _controller.draft.prescriptions[prescriptionIndex];
    final tokens = _setTokens[prescription.exerciseId]!;
    if (newIndex != oldIndex) {
      final token = tokens.removeAt(oldIndex);
      tokens.insert(newIndex, token);
    }
    final controllerIndex = newIndex > oldIndex ? newIndex + 1 : newIndex;
    _controller.reorderPlannedSets(
      prescriptionIndex,
      oldIndex,
      controllerIndex,
    );
  }

  Future<void> _addExercises() async {
    if (_controller.saving) {
      return;
    }
    final existingIds = _controller.draft.prescriptions
        .map((prescription) => prescription.exerciseId)
        .toSet();
    final choices = await Navigator.of(context).push<List<ExerciseChoice>>(
      MaterialPageRoute(
        builder: (_) => ExercisePickerScreen(initiallySelectedIds: existingIds),
      ),
    );
    if (!mounted || choices == null || _controller.saving) {
      return;
    }
    await _controller.addExercises(
      choices.where((choice) => !existingIds.contains(choice.id)).toList(),
    );
    _synchronizeTokens();
  }

  Future<void> _save() async {
    setState(() => _announcement = null);
    if (_setTargetErrors.isNotEmpty) {
      setState(() => _announcement = 'Fix invalid Planned Set targets');
      return;
    }
    try {
      if (widget.onCompleted case final onCompleted?) {
        final completed = _controller.completeDraft();
        if (completed != null) {
          onCompleted(completed);
          return;
        }
      } else {
        final id = await _controller.save();
        if (id != null && mounted) {
          widget.onSaved!(id);
          return;
        }
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _announcement = 'Could not save Template: $error');
      return;
    }
    if (!mounted) {
      return;
    }
    final errors = _controller.errors.values.toList();
    setState(() {
      _announcement = errors.isEmpty
          ? 'Could not save Template'
          : 'Template has errors. ${errors.join('. ')}';
    });
    if (_controller.errors.containsKey('name')) {
      _nameFocusNode.requestFocus();
    }
  }

  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your unsaved Template changes will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) {
      return;
    }
    setState(() => _allowPop = true);
    Navigator.pop(context);
  }

  void _setNotes(int index, String value) {
    if (!_controller.saving) {
      _controller.setNotes(index, value);
    }
  }

  void _setTargetValidity(
    Object token,
    Map<_SetTarget, String> errors,
    Map<_SetTarget, String> raw,
  ) {
    setState(() {
      _setTargetRaw[token] = Map.unmodifiable(raw);
      if (errors.isEmpty) {
        _setTargetErrors.remove(token);
      } else {
        _setTargetErrors[token] = Map.unmodifiable(errors);
      }
    });
  }
}

final class _ExerciseEditor extends StatelessWidget {
  const _ExerciseEditor({
    required this.index,
    required this.prescription,
    required this.setTokens,
    required this.targetErrors,
    required this.targetRaw,
    required this.setError,
    required this.mutationsEnabled,
    required this.onNotesChanged,
    required this.onRemove,
    required this.onAddSet,
    required this.onRemoveSet,
    required this.onUpdateSet,
    required this.onSetValidityChanged,
    required this.onReorderSets,
    required this.exerciseHandle,
    super.key,
  });

  final int index;
  final ExercisePrescriptionDraft prescription;
  final List<Object> setTokens;
  final Map<Object, Map<_SetTarget, String>> targetErrors;
  final Map<Object, Map<_SetTarget, String>> targetRaw;
  final String? setError;
  final bool mutationsEnabled;
  final ValueChanged<String> onNotesChanged;
  final VoidCallback onRemove;
  final VoidCallback onAddSet;
  final ValueChanged<int> onRemoveSet;
  final void Function(int index, PlannedSetDraft value) onUpdateSet;
  final void Function(
    Object token,
    Map<_SetTarget, String> errors,
    Map<_SetTarget, String> raw,
  )
  onSetValidityChanged;
  final ReorderCallback onReorderSets;
  final AccessibleReorderHandle exerciseHandle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    prescription.exerciseName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Remove ${prescription.exerciseName}',
                  onPressed: mutationsEnabled ? onRemove : null,
                  icon: const Icon(Icons.delete_outline),
                ),
                exerciseHandle,
              ],
            ),
            TextFormField(
              initialValue: prescription.notes,
              enabled: mutationsEnabled,
              decoration: const InputDecoration(labelText: 'Notes'),
              onChanged: mutationsEnabled ? onNotesChanged : null,
            ),
            const SizedBox(height: 12),
            Text('Planned Sets', style: Theme.of(context).textTheme.titleSmall),
            if (setError case final error?) _ValidationMessage(error),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: prescription.plannedSets.length,
              onReorderItem: onReorderSets,
              itemBuilder: (context, setIndex) {
                final value = prescription.plannedSets[setIndex];
                return _PlannedSetEditor(
                  key: ValueKey(setTokens[setIndex]),
                  token: setTokens[setIndex],
                  targetErrors: targetErrors[setTokens[setIndex]] ?? const {},
                  rawValues: targetRaw[setTokens[setIndex]] ?? const {},
                  exerciseId: prescription.exerciseId,
                  exerciseName: prescription.exerciseName,
                  index: setIndex,
                  total: prescription.plannedSets.length,
                  value: value,
                  enabled: mutationsEnabled,
                  onChanged: (updated) => onUpdateSet(setIndex, updated),
                  onRemove: () => onRemoveSet(setIndex),
                  onReorder: onReorderSets,
                  onValidityChanged: onSetValidityChanged,
                );
              },
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: mutationsEnabled ? onAddSet : null,
                icon: const Icon(Icons.add),
                label: const Text('Add set'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _PlannedSetEditor extends StatefulWidget {
  const _PlannedSetEditor({
    required this.exerciseId,
    required this.token,
    required this.targetErrors,
    required this.rawValues,
    required this.exerciseName,
    required this.index,
    required this.total,
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.onRemove,
    required this.onReorder,
    required this.onValidityChanged,
    super.key,
  });

  final int exerciseId;
  final Object token;
  final Map<_SetTarget, String> targetErrors;
  final Map<_SetTarget, String> rawValues;
  final String exerciseName;
  final int index;
  final int total;
  final PlannedSetDraft value;
  final bool enabled;
  final ValueChanged<PlannedSetDraft> onChanged;
  final VoidCallback onRemove;
  final ReorderCallback onReorder;
  final void Function(
    Object token,
    Map<_SetTarget, String> errors,
    Map<_SetTarget, String> raw,
  )
  onValidityChanged;

  @override
  State<_PlannedSetEditor> createState() => _PlannedSetEditorState();
}

final class _PlannedSetEditorState extends State<_PlannedSetEditor> {
  late final TextEditingController _weight;
  late final TextEditingController _minReps;
  late final TextEditingController _maxReps;
  late final TextEditingController _rir;
  @override
  void initState() {
    super.initState();
    _weight = TextEditingController(
      text: widget.rawValues[_SetTarget.weight] ?? _number(widget.value.weight),
    );
    _minReps = TextEditingController(
      text:
          widget.rawValues[_SetTarget.minReps] ?? _number(widget.value.minReps),
    );
    _maxReps = TextEditingController(
      text:
          widget.rawValues[_SetTarget.maxReps] ?? _number(widget.value.maxReps),
    );
    _rir = TextEditingController(
      text: widget.rawValues[_SetTarget.rir] ?? _number(widget.value.rir),
    );
  }

  @override
  void dispose() {
    _weight.dispose();
    _minReps.dispose();
    _maxReps.dispose();
    _rir.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Set ${widget.index + 1}'),
              const Spacer(),
              IconButton(
                tooltip:
                    'Remove set ${widget.index + 1} from ${widget.exerciseName}',
                onPressed: widget.enabled ? widget.onRemove : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              AccessibleReorderHandle(
                key: ValueKey('set-drag-${widget.exerciseId}-${widget.index}'),
                index: widget.index,
                label: 'set ${widget.index + 1}',
                enabled: widget.enabled,
                onMoveUp: widget.index == 0
                    ? null
                    : () => widget.onReorder(widget.index, widget.index - 1),
                onMoveDown: widget.index == widget.total - 1
                    ? null
                    : () => widget.onReorder(widget.index, widget.index + 1),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TargetField(
                label: 'Weight',
                controller: _weight,
                decimal: true,
                enabled: widget.enabled,
                errorText: widget.targetErrors[_SetTarget.weight],
                onChanged: (_) => _emit(),
              ),
              _TargetField(
                label: 'Min reps',
                controller: _minReps,
                enabled: widget.enabled,
                errorText: widget.targetErrors[_SetTarget.minReps],
                onChanged: (_) => _emit(),
              ),
              _TargetField(
                label: 'Max reps',
                controller: _maxReps,
                enabled: widget.enabled,
                errorText: widget.targetErrors[_SetTarget.maxReps],
                onChanged: (_) => _emit(),
              ),
              _TargetField(
                label: 'RIR',
                controller: _rir,
                enabled: widget.enabled,
                errorText: widget.targetErrors[_SetTarget.rir],
                onChanged: (_) => _emit(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<PlannedSetType>(
            segments: const [
              ButtonSegment(
                value: PlannedSetType.working,
                label: Text('Working'),
                icon: Icon(Icons.fitness_center),
              ),
              ButtonSegment(
                value: PlannedSetType.dropset,
                label: Text('Dropset'),
                icon: Icon(Icons.south),
              ),
            ],
            selected: {widget.value.type},
            onSelectionChanged: widget.enabled
                ? (selected) => widget.onChanged(_draft(type: selected.single))
                : null,
          ),
        ],
      ),
    );
  }

  void _emit() {
    if (!widget.enabled) {
      return;
    }
    final errors = <_SetTarget, String>{
      _SetTarget.weight: ?_numberError(_weight.text),
      _SetTarget.minReps: ?_integerError(_minReps.text),
      _SetTarget.maxReps: ?_integerError(_maxReps.text),
      _SetTarget.rir: ?_integerError(_rir.text),
    };
    widget.onValidityChanged(widget.token, errors, {
      _SetTarget.weight: _weight.text,
      _SetTarget.minReps: _minReps.text,
      _SetTarget.maxReps: _maxReps.text,
      _SetTarget.rir: _rir.text,
    });
    widget.onChanged(_draft(type: widget.value.type));
  }

  PlannedSetDraft _draft({required PlannedSetType type}) {
    return PlannedSetDraft(
      id: widget.value.id,
      weight: _nullableDouble(_weight.text),
      minReps: _nullableInt(_minReps.text),
      maxReps: _nullableInt(_maxReps.text),
      rir: _nullableInt(_rir.text),
      type: type,
    );
  }

  static String _number(num? value) => value?.toString() ?? '';
  static double? _nullableDouble(String value) =>
      value.trim().isEmpty ? null : double.tryParse(value);
  static int? _nullableInt(String value) =>
      value.trim().isEmpty ? null : int.tryParse(value);
  static String? _numberError(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final parsed = double.tryParse(trimmed);
    return parsed == null || !parsed.isFinite ? 'Enter a number' : null;
  }

  static String? _integerError(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty || int.tryParse(trimmed) != null
        ? null
        : 'Enter a whole number';
  }
}

enum _SetTarget { weight, minReps, maxReps, rir }

final class _TargetField extends StatelessWidget {
  const _TargetField({
    required this.label,
    required this.controller,
    required this.enabled,
    required this.errorText,
    required this.onChanged,
    this.decimal = false,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final String? errorText;
  final ValueChanged<String> onChanged;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      child: TextField(
        controller: controller,
        enabled: enabled,
        decoration: InputDecoration(labelText: label, errorText: errorText),
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        onChanged: onChanged,
      ),
    );
  }
}

final class _ValidationMessage extends StatelessWidget {
  const _ValidationMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 18,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
