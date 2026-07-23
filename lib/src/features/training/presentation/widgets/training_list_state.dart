import 'package:flutter/material.dart';

import '../training_providers.dart';

class TrainingListSkeleton extends StatelessWidget {
  const TrainingListSkeleton({super.key, required this.keyPrefix});

  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Semantics(
      label: 'Loading Training',
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: 3,
        itemBuilder: (context, index) => Card(
          key: Key('$keyPrefix-skeleton-$index'),
          child: SizedBox(
            height: 80,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 144, height: 18, color: color),
                  const SizedBox(height: 12),
                  Container(width: 220, height: 14, color: color),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TrainingListEmpty extends StatelessWidget {
  const TrainingListEmpty({
    super.key,
    required this.contentType,
    required this.query,
    this.archived = false,
  });

  final TrainingContentType contentType;
  final String query;
  final bool archived;

  @override
  Widget build(BuildContext context) {
    final noun = contentType == TrainingContentType.templates
        ? 'Templates'
        : 'Routines';
    final trimmedQuery = query.trim();
    if (trimmedQuery.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No $noun match “$trimmedQuery”',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (archived) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('No archived $noun'),
        ),
      );
    }

    final description = contentType == TrainingContentType.templates
        ? 'Templates are individual training days. Use + to create one.'
        : 'Routines are optional ordered groupings of training-day Templates. '
              'Use + to create one.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('No $noun yet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(description, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class TrainingListError extends StatelessWidget {
  const TrainingListError({
    super.key,
    required this.error,
    required this.onRetry,
  });

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
            Text(
              'Training could not be loaded',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('$error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
