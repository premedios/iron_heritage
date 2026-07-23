import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'training_providers.dart';
import 'widgets/training_list_cards.dart';
import 'widgets/training_list_state.dart';

class ArchivedTrainingScreen extends ConsumerWidget {
  const ArchivedTrainingScreen({super.key, required this.contentType});

  final TrainingContentType contentType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = contentType == TrainingContentType.templates;
    final title = templates ? 'Archived Templates' : 'Archived Routines';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: templates
          ? _ArchivedTemplates(
              onRestore: (id, name) => _confirmRestore(
                context,
                ref,
                id: id,
                name: name,
                contentType: contentType,
              ),
            )
          : _ArchivedRoutines(
              onRestore: (id, name) => _confirmRestore(
                context,
                ref,
                id: id,
                name: name,
                contentType: contentType,
              ),
            ),
    );
  }

  Future<void> _confirmRestore(
    BuildContext context,
    WidgetRef ref, {
    required int id,
    required String name,
    required TrainingContentType contentType,
  }) async {
    final noun = contentType == TrainingContentType.templates
        ? 'Template'
        : 'Routine';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Restore $noun?'),
        content: Text('Restore $name to the active library?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      final repository = ref.read(trainingRepositoryProvider);
      if (contentType == TrainingContentType.templates) {
        await repository.setTemplateArchived(id, archived: false);
      } else {
        await repository.setRoutineArchived(id, archived: false);
      }
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not restore $noun: $error')),
        );
      }
    }
  }
}

class _ArchivedTemplates extends ConsumerWidget {
  const _ArchivedTemplates({required this.onRestore});

  final Future<void> Function(int id, String name) onRestore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const request = (archived: true, query: '');
    final summaries = ref.watch(templateSummariesProvider(request));
    return summaries.when(
      data: (items) {
        if (items.isEmpty) {
          return const TrainingListEmpty(
            contentType: TrainingContentType.templates,
            query: '',
            archived: true,
          );
        }
        return ListView.separated(
          key: const PageStorageKey<String>('archived-template-list'),
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 4),
          itemBuilder: (context, index) {
            final item = items[index];
            return WorkoutTemplateCard(
              summary: item,
              onTap: () => onRestore(item.id, item.name),
              trailing: IconButton(
                tooltip: 'Restore Template',
                onPressed: () => onRestore(item.id, item.name),
                icon: const Icon(Icons.restore),
              ),
            );
          },
        );
      },
      loading: () => const TrainingListSkeleton(keyPrefix: 'archived-template'),
      error: (error, _) => TrainingListError(
        error: error,
        onRetry: () => ref.invalidate(templateSummariesProvider(request)),
      ),
    );
  }
}

class _ArchivedRoutines extends ConsumerWidget {
  const _ArchivedRoutines({required this.onRestore});

  final Future<void> Function(int id, String name) onRestore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const request = (archived: true, query: '');
    final summaries = ref.watch(routineSummariesProvider(request));
    return summaries.when(
      data: (items) {
        if (items.isEmpty) {
          return const TrainingListEmpty(
            contentType: TrainingContentType.routines,
            query: '',
            archived: true,
          );
        }
        return ListView.separated(
          key: const PageStorageKey<String>('archived-routine-list'),
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 4),
          itemBuilder: (context, index) {
            final item = items[index];
            return RoutineCard(
              summary: item,
              onTap: () => onRestore(item.id, item.name),
              trailing: IconButton(
                tooltip: 'Restore Routine',
                onPressed: () => onRestore(item.id, item.name),
                icon: const Icon(Icons.restore),
              ),
            );
          },
        );
      },
      loading: () => const TrainingListSkeleton(keyPrefix: 'archived-routine'),
      error: (error, _) => TrainingListError(
        error: error,
        onRetry: () => ref.invalidate(routineSummariesProvider(request)),
      ),
    );
  }
}
