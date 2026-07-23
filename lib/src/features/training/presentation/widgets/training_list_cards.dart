import 'package:flutter/material.dart';

import '../../domain/training_models.dart';

class WorkoutTemplateCard extends StatelessWidget {
  const WorkoutTemplateCard({
    super.key,
    required this.summary,
    required this.onTap,
    this.trailing,
  });

  final WorkoutTemplateSummary summary;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final count = summary.exerciseNames.length;
    final countLabel = count == 1 ? '1 exercise' : '$count exercises';
    return Semantics(
      container: true,
      button: true,
      label: '${summary.name}, $countLabel',
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          summary.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(countLabel),
                        if (summary.exerciseNames.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            summary.exerciseNames.join(' • '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RoutineCard extends StatelessWidget {
  const RoutineCard({
    super.key,
    required this.summary,
    required this.onTap,
    this.trailing,
  });

  final RoutineSummary summary;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final count = summary.templateNames.length;
    final countLabel = count == 1 ? '1 Template' : '$count Templates';
    return Semantics(
      container: true,
      button: true,
      label: '${summary.name}, $countLabel',
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          summary.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(countLabel),
                        if (summary.templateNames.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            summary.templateNames.join(' • '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
