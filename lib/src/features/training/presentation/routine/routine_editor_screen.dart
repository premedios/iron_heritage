import 'package:flutter/material.dart';

import '../../data/training_repository.dart';
import '../../domain/training_models.dart';
import '../widgets/accessible_reorder_handle.dart';
import 'routine_editor_controller.dart';
import 'template_picker_sheet.dart';

final class RoutineEditorScreen extends StatefulWidget {
  const RoutineEditorScreen({
    required this.initial,
    required this.repository,
    required this.onSaved,
    super.key,
  });

  final RoutineDraft initial;
  final TrainingRepository repository;
  final ValueChanged<int> onSaved;

  @override
  State<RoutineEditorScreen> createState() => _RoutineEditorScreenState();
}

final class _RoutineEditorScreenState extends State<RoutineEditorScreen> {
  late final RoutineEditorController _controller;
  late final TextEditingController _nameController;
  final _nameFocusNode = FocusNode();
  bool _allowPop = false;
  String? _announcement;

  @override
  void initState() {
    super.initState();
    _controller = RoutineEditorController(
      repository: widget.repository,
      initial: widget.initial,
    )..addListener(_onControllerChanged);
    _nameController = TextEditingController(text: widget.initial.name);
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
    final busy = _controller.saving;
    return PopScope<Object?>(
      canPop: !busy && (_allowPop || !_controller.dirty),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !busy) {
          _confirmDiscard();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(draft.id == null ? 'New Routine' : 'Edit Routine'),
          actions: [
            TextButton(
              onPressed: busy ? null : _save,
              child: const Text('Save'),
            ),
          ],
          bottom: busy
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(3),
                  child: LinearProgressIndicator(
                    semanticsLabel: 'Saving Routine',
                  ),
                )
              : null,
        ),
        body: AbsorbPointer(
          absorbing: busy,
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
                enabled: !busy,
                decoration: InputDecoration(
                  labelText: 'Routine name',
                  errorText: _controller.errors['name'],
                ),
                onChanged: (value) {
                  if (!busy) {
                    _controller.setName(value);
                  }
                },
              ),
              const SizedBox(height: 16),
              if (_controller.errors['templates'] case final error?)
                _ValidationMessage(error),
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: draft.templates.length,
                onReorderItem: _reorderTemplates,
                itemBuilder: (context, index) {
                  final template = draft.templates[index];
                  return _TemplatePreview(
                    key: ObjectKey(template),
                    template: template,
                    nameError: _controller.errors['templates.$index.name'],
                    removeEnabled: !busy,
                    onRemove: () => _removeTemplate(index),
                    handle: AccessibleReorderHandle(
                      key: ValueKey('template-drag-$index'),
                      index: index,
                      label: template.name,
                      enabled: !busy,
                      onMoveUp: index == 0
                          ? null
                          : () => _reorderTemplates(index, index - 1),
                      onMoveDown: index == draft.templates.length - 1
                          ? null
                          : () => _reorderTemplates(index, index + 1),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: busy ? null : _addTemplates,
                icon: const Icon(Icons.add),
                label: const Text('Add template'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _reorderTemplates(int oldIndex, int newIndex) {
    if (_controller.saving) {
      return;
    }
    final controllerIndex = newIndex > oldIndex ? newIndex + 1 : newIndex;
    _controller.reorderTemplates(oldIndex, controllerIndex);
  }

  Future<void> _addTemplates() async {
    if (_controller.saving) {
      return;
    }
    final selected = await showModalBottomSheet<List<WorkoutTemplateDraft>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TemplatePickerSheet(repository: widget.repository),
    );
    if (!mounted ||
        _controller.saving ||
        selected == null ||
        selected.isEmpty) {
      return;
    }
    _controller.addExistingTemplates(selected);
  }

  void _removeTemplate(int index) {
    if (!_controller.saving) {
      _controller.removeTemplate(index);
    }
  }

  Future<void> _save() async {
    if (_controller.saving) {
      return;
    }
    setState(() => _announcement = null);
    try {
      final id = await _controller.save();
      if (id != null && mounted) {
        widget.onSaved(id);
        return;
      }
    } catch (error) {
      if (mounted) {
        setState(() => _announcement = 'Could not save Routine: $error');
      }
      return;
    }
    if (!mounted) {
      return;
    }
    final errors = _controller.errors.values.toList();
    setState(() {
      _announcement = errors.isEmpty
          ? 'Could not save Routine'
          : 'Routine has errors. ${errors.join('. ')}';
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
        content: const Text('Your unsaved Routine changes will be lost.'),
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
}

final class _TemplatePreview extends StatelessWidget {
  const _TemplatePreview({
    required this.template,
    required this.nameError,
    required this.removeEnabled,
    required this.onRemove,
    required this.handle,
    super.key,
  });

  final WorkoutTemplateDraft template;
  final String? nameError;
  final bool removeEnabled;
  final VoidCallback onRemove;
  final AccessibleReorderHandle handle;

  @override
  Widget build(BuildContext context) {
    final exerciseNames = template.prescriptions
        .map((prescription) => prescription.exerciseName)
        .toList();
    final count = exerciseNames.length;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text('$count ${count == 1 ? 'exercise' : 'exercises'}'),
                  if (exerciseNames.isNotEmpty) Text(exerciseNames.join(', ')),
                  if (nameError case final error?) _ValidationMessage(error),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Remove ${template.name}',
              onPressed: removeEnabled ? onRemove : null,
              icon: const Icon(Icons.delete_outline),
            ),
            handle,
          ],
        ),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}
