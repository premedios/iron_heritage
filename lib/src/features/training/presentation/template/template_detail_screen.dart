import 'package:flutter/material.dart';

import '../../data/training_repository.dart';
import '../../domain/training_models.dart';

final class TemplateDetailScreen extends StatefulWidget {
  const TemplateDetailScreen({
    required this.templateId,
    required this.repository,
    required this.onStartWorkout,
    required this.onEdit,
    required this.onArchived,
    this.allowArchive = true,
    super.key,
  });

  final int templateId;
  final TrainingRepository repository;
  final VoidCallback onStartWorkout;
  final ValueChanged<WorkoutTemplateDraft> onEdit;
  final VoidCallback onArchived;
  final bool allowArchive;

  @override
  State<TemplateDetailScreen> createState() => _TemplateDetailScreenState();
}

final class _TemplateDetailScreenState extends State<TemplateDetailScreen> {
  WorkoutTemplateDraft? _template;
  Object? _loadError;
  bool _loading = true;
  bool _writing = false;
  int _loadGeneration = 0;
  int _operationGeneration = 0;

  bool get _archived => _template?.archivedAt != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TemplateDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final loadIdentityChanged =
        oldWidget.templateId != widget.templateId ||
        !identical(oldWidget.repository, widget.repository);
    if (loadIdentityChanged) {
      _operationGeneration++;
      _writing = false;
      _template = null;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final template = _template;
    return Scaffold(
      appBar: AppBar(
        title: Text(template?.name ?? 'Template'),
        actions: [
          if (template != null)
            SizedBox.square(
              dimension: 48,
              child: Semantics(
                label: 'Edit Template',
                button: true,
                enabled: !_writing,
                excludeSemantics: true,
                child: IconButton(
                  tooltip: 'Edit Template',
                  onPressed: _writing ? null : () => widget.onEdit(template),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ),
            ),
          if (template != null && widget.allowArchive)
            SizedBox.square(
              dimension: 48,
              child: PopupMenuButton<_TemplateAction>(
                tooltip: 'More Template actions',
                enabled: !_writing,
                onSelected: (action) {
                  switch (action) {
                    case _TemplateAction.archive:
                      _confirmArchiveChange(archived: true);
                    case _TemplateAction.restore:
                      _confirmArchiveChange(archived: false);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: _archived
                        ? _TemplateAction.restore
                        : _TemplateAction.archive,
                    child: Text(_archived ? 'Restore' : 'Archive'),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: switch ((template, _loadError, _loading)) {
        (null, _, true) => const _TemplateDetailSkeleton(),
        (null, final error?, false) => _LoadError(error: error, onRetry: _load),
        (null, null, false) => _LoadError(
          error: 'Template not found',
          onRetry: _load,
        ),
        (final value?, _, _) => _TemplateDetail(
          template: value,
          writing: _writing,
          onStartWorkout: widget.onStartWorkout,
        ),
      },
    );
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final loaded = await widget.repository.loadTemplate(widget.templateId);
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _template = loaded;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  Future<void> _confirmArchiveChange({required bool archived}) async {
    final template = _template;
    if (template == null || _writing) {
      return;
    }
    final generation = ++_operationGeneration;
    final templateId = widget.templateId;
    final repository = widget.repository;
    final verb = archived ? 'Archive' : 'Restore';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$verb Template?'),
        content: Text(
          archived
              ? 'Archive ${template.name}? You can restore it later.'
              : 'Restore ${template.name} to the active library?',
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
    if (confirmed == true &&
        _isCurrentOperation(
          generation: generation,
          templateId: templateId,
          repository: repository,
        )) {
      await _setArchived(
        archived: archived,
        generation: generation,
        templateId: templateId,
        repository: repository,
        template: template,
      );
    }
  }

  Future<void> _setArchived({
    required bool archived,
    required int generation,
    required int templateId,
    required TrainingRepository repository,
    required WorkoutTemplateDraft template,
  }) async {
    if (_writing ||
        !_isCurrentOperation(
          generation: generation,
          templateId: templateId,
          repository: repository,
        )) {
      return;
    }
    setState(() => _writing = true);
    try {
      await repository.setTemplateArchived(templateId, archived: archived);
      if (!_isCurrentOperation(
        generation: generation,
        templateId: templateId,
        repository: repository,
      )) {
        return;
      }
      setState(() {
        _template = _withArchivedAt(template, archived ? DateTime.now() : null);
        _writing = false;
      });
      if (archived) {
        widget.onArchived();
      }
    } on Object catch (error) {
      if (!_isCurrentOperation(
        generation: generation,
        templateId: templateId,
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
        SnackBar(content: Text('Could not $verb Template: $message')),
      );
    }
  }

  bool _isCurrentOperation({
    required int generation,
    required int templateId,
    required TrainingRepository repository,
  }) {
    return mounted &&
        generation == _operationGeneration &&
        templateId == widget.templateId &&
        identical(repository, widget.repository);
  }

  static WorkoutTemplateDraft _withArchivedAt(
    WorkoutTemplateDraft template,
    DateTime? archivedAt,
  ) {
    return WorkoutTemplateDraft(
      id: template.id,
      routineId: template.routineId,
      archivedAt: archivedAt,
      name: template.name,
      prescriptions: template.prescriptions,
    );
  }
}

enum _TemplateAction { archive, restore }

final class _LoadError extends StatelessWidget {
  const _LoadError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = 'Could not load Template: $error';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              container: true,
              liveRegion: true,
              label: message,
              excludeSemantics: true,
              child: Text(message, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

final class _TemplateDetailSkeleton extends StatelessWidget {
  const _TemplateDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Semantics(
      key: const Key('template-detail-skeleton'),
      container: true,
      label: 'Loading Template',
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
                const SizedBox(height: 16),
                _SkeletonBar(width: 88, color: color),
                const SizedBox(height: 10),
                _SkeletonBar(width: double.infinity, color: color),
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

final class _TemplateDetail extends StatelessWidget {
  const _TemplateDetail({
    required this.template,
    required this.writing,
    required this.onStartWorkout,
  });

  final WorkoutTemplateDraft template;
  final bool writing;
  final VoidCallback onStartWorkout;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (writing)
          Semantics(
            container: true,
            label: template.archivedAt == null
                ? 'Archiving Template'
                : 'Restoring Template',
            excludeSemantics: true,
            child: const LinearProgressIndicator(),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: template.prescriptions.length,
            itemBuilder: (context, index) {
              final prescription = template.prescriptions[index];
              final count = prescription.plannedSets.length;
              return Semantics(
                container: true,
                label:
                    'Exercise ${index + 1} of '
                    '${template.prescriptions.length}, '
                    '${prescription.exerciseName}, '
                    '$count Planned ${count == 1 ? 'Set' : 'Sets'}',
                child: _ExerciseCard(
                  key: ValueKey(prescription.id ?? prescription.exerciseId),
                  prescription: prescription,
                ),
              );
            },
          ),
        ),
        if (template.archivedAt == null)
          SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: writing ? null : onStartWorkout,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Workout'),
              ),
            ),
          ),
      ],
    );
  }
}

final class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.prescription, super.key});

  final ExercisePrescriptionDraft prescription;

  @override
  Widget build(BuildContext context) {
    final notes = prescription.notes?.trim();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              prescription.exerciseName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Notes', style: Theme.of(context).textTheme.labelMedium),
              Text(notes),
            ],
            const SizedBox(height: 12),
            Text('Planned Sets', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            for (
              var index = 0;
              index < prescription.plannedSets.length;
              index++
            )
              _PlannedSetRow(
                index: index,
                set: prescription.plannedSets[index],
              ),
          ],
        ),
      ),
    );
  }
}

final class _PlannedSetRow extends StatelessWidget {
  const _PlannedSetRow({required this.index, required this.set});

  final int index;
  final PlannedSetDraft set;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Set ${index + 1}')),
              Text(set.type == PlannedSetType.working ? 'Working' : 'Dropset'),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text('Weight: ${_number(set.weight)}'),
              Text('Reps: ${_reps(set.minReps, set.maxReps)}'),
              Text('RIR: ${_number(set.rir)}'),
            ],
          ),
        ],
      ),
    );
  }

  static String _number(num? value) {
    if (value == null) {
      return '—';
    }
    return value is double && value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }

  static String _reps(int? minimum, int? maximum) {
    return switch ((minimum, maximum)) {
      (final min?, final max?) => '$min–$max',
      (final min?, null) => '$min+',
      (null, final max?) => 'Up to $max',
      (null, null) => '—',
    };
  }
}
