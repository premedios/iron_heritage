import 'package:flutter/material.dart';

import '../../data/training_repository.dart';
import '../../domain/training_models.dart';
import '../template/template_detail_screen.dart';
import '../template/template_editor_screen.dart';

final class RoutineDetailScreen extends StatefulWidget {
  const RoutineDetailScreen({
    required this.routineId,
    required this.repository,
    required this.onStartWorkout,
    required this.onEdit,
    super.key,
  });

  final int routineId;
  final TrainingRepository repository;
  final ValueChanged<int> onStartWorkout;
  final ValueChanged<RoutineDraft> onEdit;

  @override
  State<RoutineDetailScreen> createState() => _RoutineDetailScreenState();
}

final class _RoutineDetailScreenState extends State<RoutineDetailScreen> {
  RoutineDraft? _routine;
  Object? _loadError;
  bool _loading = true;
  bool _writing = false;
  int _loadGeneration = 0;
  int _operationGeneration = 0;

  bool get _archived => _routine?.archivedAt != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant RoutineDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final identityChanged =
        oldWidget.routineId != widget.routineId ||
        !identical(oldWidget.repository, widget.repository);
    if (identityChanged) {
      _operationGeneration++;
      _writing = false;
      _routine = null;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final routine = _routine;
    return Scaffold(
      appBar: AppBar(
        title: Text(routine?.name ?? 'Routine'),
        actions: [
          if (routine != null)
            SizedBox.square(
              dimension: 48,
              child: Semantics(
                label: 'Edit Routine',
                button: true,
                enabled: !_writing,
                excludeSemantics: true,
                child: IconButton(
                  tooltip: 'Edit Routine',
                  onPressed: _writing ? null : () => widget.onEdit(routine),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ),
            ),
          if (routine != null)
            SizedBox.square(
              dimension: 48,
              child: PopupMenuButton<_RoutineAction>(
                tooltip: 'More Routine actions',
                enabled: !_writing,
                onSelected: (action) {
                  switch (action) {
                    case _RoutineAction.archive:
                      _confirmArchiveChange(archived: true);
                    case _RoutineAction.restore:
                      _confirmArchiveChange(archived: false);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: _archived
                        ? _RoutineAction.restore
                        : _RoutineAction.archive,
                    child: Text(_archived ? 'Restore' : 'Archive'),
                  ),
                ],
              ),
            ),
        ],
        bottom: _writing
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  semanticsLabel: _archived
                      ? 'Restoring Routine'
                      : 'Archiving Routine',
                ),
              )
            : null,
      ),
      body: switch ((routine, _loadError, _loading)) {
        (null, _, true) => const _RoutineDetailSkeleton(),
        (null, final error?, false) => _LoadError(error: error, onRetry: _load),
        (null, null, false) => _LoadError(
          error: 'Routine not found',
          onRetry: _load,
        ),
        (final value?, _, _) => _RoutineTemplateList(
          routine: value,
          enabled: !_writing,
          onOpen: _openTemplate,
        ),
      },
    );
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final routineId = widget.routineId;
    final repository = widget.repository;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final loaded = await repository.loadRoutine(routineId);
      if (!_isCurrentLoad(
        generation: generation,
        routineId: routineId,
        repository: repository,
      )) {
        return;
      }
      setState(() {
        _routine = loaded;
        _loading = false;
      });
    } on Object catch (error) {
      if (!_isCurrentLoad(
        generation: generation,
        routineId: routineId,
        repository: repository,
      )) {
        return;
      }
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  Future<void> _openTemplate(WorkoutTemplateDraft template) async {
    final templateId = template.id;
    if (templateId == null || _writing) {
      return;
    }
    final routineId = widget.routineId;
    final repository = widget.repository;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _OwnedTemplateDetailRoute(
          initial: template,
          repository: repository,
          onStartWorkout: (templateId) {
            if (mounted &&
                routineId == widget.routineId &&
                identical(repository, widget.repository)) {
              widget.onStartWorkout(templateId);
            }
          },
        ),
      ),
    );
    if (mounted &&
        routineId == widget.routineId &&
        identical(repository, widget.repository)) {
      await _load();
    }
  }

  Future<void> _confirmArchiveChange({required bool archived}) async {
    final routine = _routine;
    if (routine == null || _writing) {
      return;
    }
    final generation = ++_operationGeneration;
    final routineId = widget.routineId;
    final repository = widget.repository;
    final verb = archived ? 'Archive' : 'Restore';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$verb Routine?'),
        content: Text(
          archived
              ? 'Archive ${routine.name}? Its Templates will be preserved.'
              : 'Restore ${routine.name} to the active library?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(verb),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !_isCurrentOperation(
          generation: generation,
          routineId: routineId,
          repository: repository,
        )) {
      return;
    }
    await _setArchived(
      archived: archived,
      generation: generation,
      routineId: routineId,
      repository: repository,
      routine: routine,
    );
  }

  Future<void> _setArchived({
    required bool archived,
    required int generation,
    required int routineId,
    required TrainingRepository repository,
    required RoutineDraft routine,
  }) async {
    if (_writing ||
        !_isCurrentOperation(
          generation: generation,
          routineId: routineId,
          repository: repository,
        )) {
      return;
    }
    setState(() => _writing = true);
    try {
      await repository.setRoutineArchived(routineId, archived: archived);
      if (!_isCurrentOperation(
        generation: generation,
        routineId: routineId,
        repository: repository,
      )) {
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _routine = RoutineDraft(
          id: routine.id,
          archivedAt: archived ? DateTime.now() : null,
          name: routine.name,
          templates: routine.templates,
        );
        _writing = false;
      });
      await Navigator.of(context).maybePop();
    } on Object catch (error) {
      if (!_isCurrentOperation(
        generation: generation,
        routineId: routineId,
        repository: repository,
      )) {
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() => _writing = false);
      final message = error is DuplicateTrainingName
          ? error.message
          : error.toString();
      final verb = archived ? 'archive' : 'restore';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not $verb Routine: $message')),
      );
    }
  }

  bool _isCurrentLoad({
    required int generation,
    required int routineId,
    required TrainingRepository repository,
  }) {
    return mounted &&
        generation == _loadGeneration &&
        routineId == widget.routineId &&
        identical(repository, widget.repository);
  }

  bool _isCurrentOperation({
    required int generation,
    required int routineId,
    required TrainingRepository repository,
  }) {
    return mounted &&
        generation == _operationGeneration &&
        routineId == widget.routineId &&
        identical(repository, widget.repository);
  }
}

enum _RoutineAction { archive, restore }

final class _RoutineTemplateList extends StatelessWidget {
  const _RoutineTemplateList({
    required this.routine,
    required this.enabled,
    required this.onOpen,
  });

  final RoutineDraft routine;
  final bool enabled;
  final ValueChanged<WorkoutTemplateDraft> onOpen;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: routine.templates.length,
      itemBuilder: (context, index) {
        final template = routine.templates[index];
        final count = template.prescriptions.length;
        final countLabel = '$count ${count == 1 ? 'exercise' : 'exercises'}';
        return Semantics(
          container: true,
          label:
              'Template ${index + 1} of ${routine.templates.length}, '
              '${template.name}, $countLabel',
          button: true,
          enabled: enabled,
          excludeSemantics: true,
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? () => onOpen(template) : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 72),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        template.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(countLabel),
                      if (template.prescriptions.isNotEmpty)
                        Text(
                          template.prescriptions
                              .map((item) => item.exerciseName)
                              .join(', '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

final class _OwnedTemplateDetailRoute extends StatefulWidget {
  const _OwnedTemplateDetailRoute({
    required this.initial,
    required this.repository,
    required this.onStartWorkout,
  });

  final WorkoutTemplateDraft initial;
  final TrainingRepository repository;
  final ValueChanged<int> onStartWorkout;

  @override
  State<_OwnedTemplateDetailRoute> createState() =>
      _OwnedTemplateDetailRouteState();
}

final class _OwnedTemplateDetailRouteState
    extends State<_OwnedTemplateDetailRoute> {
  late WorkoutTemplateDraft _template;
  bool _copying = false;
  String? _copyError;
  int _detailRevision = 0;
  int _operationGeneration = 0;

  int get _templateId => _template.id!;

  @override
  void initState() {
    super.initState();
    _template = widget.initial;
  }

  @override
  void didUpdateWidget(covariant _OwnedTemplateDetailRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    final identityChanged =
        oldWidget.initial.id != widget.initial.id ||
        !identical(oldWidget.repository, widget.repository);
    if (identityChanged) {
      _operationGeneration++;
      _template = widget.initial;
      _copying = false;
      _copyError = null;
      _detailRevision++;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TemplateDetailScreen(
        key: ValueKey((_templateId, _detailRevision)),
        templateId: _templateId,
        repository: widget.repository,
        onStartWorkout: () => widget.onStartWorkout(_templateId),
        onEdit: _editTemplate,
        onArchived: _refreshTemplate,
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_copyError case final error?)
              Semantics(
                container: true,
                liveRegion: true,
                label: error,
                excludeSemantics: true,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _copying ? null : _saveCopy,
                icon: _copying
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          semanticsLabel: 'Saving Template copy',
                        ),
                      )
                    : const Icon(Icons.copy_outlined),
                label: const Text('Save copy to Templates'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editTemplate(WorkoutTemplateDraft template) async {
    if (_copying) {
      return;
    }
    _template = template;
    final generation = _operationGeneration;
    final templateId = _templateId;
    final repository = widget.repository;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TemplateEditorScreen.persisted(
          initial: template,
          repository: repository,
          onSaved: (_) => Navigator.of(context).pop(),
        ),
      ),
    );
    if (_isCurrent(
      generation: generation,
      templateId: templateId,
      repository: repository,
    )) {
      await _refreshTemplate();
    }
  }

  Future<void> _refreshTemplate() async {
    final generation = _operationGeneration;
    final templateId = _templateId;
    final repository = widget.repository;
    try {
      final loaded = await repository.loadTemplate(templateId);
      if (loaded == null ||
          !_isCurrent(
            generation: generation,
            templateId: templateId,
            repository: repository,
          )) {
        return;
      }
      setState(() {
        _template = loaded;
        _detailRevision++;
      });
    } on Object {
      // The embedded detail owns its load failure and retry state.
    }
  }

  Future<void> _saveCopy() async {
    if (_copying) {
      return;
    }
    final generation = _operationGeneration;
    final templateId = _templateId;
    final repository = widget.repository;
    final templateName = _template.name;
    setState(() {
      _copying = true;
      _copyError = null;
    });
    try {
      await repository.saveRoutineTemplateAsStandalone(templateId);
      if (!_isCurrent(
        generation: generation,
        templateId: templateId,
        repository: repository,
      )) {
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() => _copying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$templateName saved to Templates')),
      );
    } on Object catch (error) {
      if (!_isCurrent(
        generation: generation,
        templateId: templateId,
        repository: repository,
      )) {
        return;
      }
      setState(() {
        _copying = false;
        _copyError = error is DuplicateTrainingName
            ? error.message
            : 'Could not save copy: $error';
      });
    }
  }

  bool _isCurrent({
    required int generation,
    required int templateId,
    required TrainingRepository repository,
  }) {
    return mounted &&
        generation == _operationGeneration &&
        templateId == _templateId &&
        identical(repository, widget.repository);
  }
}

final class _LoadError extends StatelessWidget {
  const _LoadError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Could not load Routine: $error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

final class _RoutineDetailSkeleton extends StatelessWidget {
  const _RoutineDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Semantics(
      key: const Key('routine-detail-skeleton'),
      container: true,
      label: 'Loading Routine',
      excludeSemantics: true,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: 2,
        itemBuilder: (context, index) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBar(width: 152, color: color),
                const SizedBox(height: 12),
                _SkeletonBar(width: 88, color: color),
                const SizedBox(height: 8),
                _SkeletonBar(width: 220, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
