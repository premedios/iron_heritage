import 'package:flutter/material.dart';

import '../../data/training_repository.dart';
import '../../domain/training_models.dart';
import '../template/template_editor_screen.dart';

final class TemplatePickerSheet extends StatefulWidget {
  const TemplatePickerSheet({required this.repository, super.key});

  final TrainingRepository repository;

  @override
  State<TemplatePickerSheet> createState() => _TemplatePickerSheetState();
}

final class _TemplatePickerSheetState extends State<TemplatePickerSheet> {
  final _selectedIds = <int>[];
  final _created = <WorkoutTemplateDraft>[];
  late Stream<List<WorkoutTemplateSummary>> _summaries;
  bool _loading = false;
  String? _error;

  int get _count => _selectedIds.length + _created.length;

  @override
  void initState() {
    super.initState();
    _watch();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: AbsorbPointer(
          absorbing: _loading,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                title: const Text('Add Templates'),
                trailing: IconButton(
                  tooltip: 'Close',
                  onPressed: _loading ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _createNew,
                  icon: const Icon(Icons.add),
                  label: const Text('Create new'),
                ),
              ),
              if (_created.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var index = 0; index < _created.length; index++)
                        InputChip(
                          label: Text(_created[index].name),
                          onDeleted: _loading
                              ? null
                              : () => setState(() => _created.removeAt(index)),
                        ),
                    ],
                  ),
                ),
              if (_error case final error?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Semantics(
                    container: true,
                    liveRegion: true,
                    label: error,
                    child: Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: StreamBuilder<List<WorkoutTemplateSummary>>(
                  stream: _summaries,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Could not load Templates: ${snapshot.error}'),
                            const SizedBox(height: 8),
                            FilledButton(
                              onPressed: _loading
                                  ? null
                                  : () => setState(_watch),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          semanticsLabel: 'Loading Templates',
                        ),
                      );
                    }

                    final summaries = snapshot.data!;
                    final availableIds = summaries
                        .map((summary) => summary.id)
                        .toSet();
                    final unavailableIds = _selectedIds
                        .where((id) => !availableIds.contains(id))
                        .toSet();
                    if (unavailableIds.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) {
                          return;
                        }
                        setState(
                          () =>
                              _selectedIds.removeWhere(unavailableIds.contains),
                        );
                      });
                    }
                    if (summaries.isEmpty) {
                      return const Center(
                        child: Text('No standalone Templates yet'),
                      );
                    }
                    return ListView.builder(
                      itemCount: summaries.length,
                      itemBuilder: (context, index) {
                        final summary = summaries[index];
                        return CheckboxListTile(
                          key: ValueKey('template-choice-${summary.id}'),
                          value: _selectedIds.contains(summary.id),
                          title: Text(summary.name),
                          subtitle: Text(
                            _exerciseSummary(summary.exerciseNames),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: _loading
                              ? null
                              : (_) => _toggle(summary.id),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: _loading || _count == 0 ? null : _complete,
                  child: _loading
                      ? const SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            semanticsLabel: 'Loading selected Templates',
                          ),
                        )
                      : Text(
                          'Add $_count ${_count == 1 ? 'template' : 'templates'}',
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _watch() {
    _summaries = widget.repository.watchTemplates(archived: false);
  }

  void _toggle(int id) {
    setState(() {
      if (_selectedIds.remove(id)) {
        return;
      }
      _selectedIds.add(id);
    });
  }

  Future<void> _createNew() async {
    final created = await Navigator.of(context).push<WorkoutTemplateDraft>(
      MaterialPageRoute(
        builder: (_) => TemplateEditorScreen.embedded(
          initial: WorkoutTemplateDraft(name: '', prescriptions: const []),
          repository: widget.repository,
          onCompleted: (draft) => Navigator.of(context).pop(draft),
        ),
      ),
    );
    if (!mounted || created == null) {
      return;
    }
    setState(() {
      _created.add(created.deepCopy());
      _error = null;
    });
  }

  Future<void> _complete() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final selected = <WorkoutTemplateDraft>[];
      for (final id in _selectedIds) {
        final template = await widget.repository.loadTemplate(id);
        if (template == null) {
          throw StateError('Selected Template is no longer available');
        }
        selected.add(template);
      }
      selected.addAll(_created);
      if (mounted) {
        Navigator.pop(context, selected);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not add Templates: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  static String _exerciseSummary(List<String> exerciseNames) {
    final count = exerciseNames.length;
    if (count == 0) {
      return 'No exercises';
    }
    return '$count ${count == 1 ? 'exercise' : 'exercises'} • '
        '${exerciseNames.join(', ')}';
  }
}
