import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../domain/smart_alternatives_service.dart';

Future<void> showSmartAlternativesBottomSheet({
  required BuildContext context,
  required Exercise occupiedExercise,
  required List<Exercise> allExercises,
  required ValueChanged<Exercise> onSelectAlternative,
  required VoidCallback onSkip,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return SmartAlternativesBottomSheet(
        occupiedExercise: occupiedExercise,
        allExercises: allExercises,
        onSelectAlternative: onSelectAlternative,
        onSkip: onSkip,
      );
    },
  );
}

class SmartAlternativesBottomSheet extends ConsumerWidget {
  final Exercise occupiedExercise;
  final List<Exercise> allExercises;
  final ValueChanged<Exercise> onSelectAlternative;
  final VoidCallback onSkip;

  const SmartAlternativesBottomSheet({
    super.key,
    required this.occupiedExercise,
    required this.allExercises,
    required this.onSelectAlternative,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(smartAlternativesServiceProvider);
    final alternatives = service.findAlternatives(
      occupiedExercise: occupiedExercise,
      allExercises: allExercises,
    );

    final mediaQuery = MediaQuery.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: mediaQuery.size.height * 0.75,
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 16,
        right: 16,
        bottom: mediaQuery.padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle indicator
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Text(
            'Smart Alternatives',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Occupied: ${occupiedExercise.name} (${occupiedExercise.equipment?.join(", ") ?? "No equipment"})',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 16),

          // List of Alternatives or Empty State
          Expanded(
            child: alternatives.isEmpty
                ? Center(
                    child: Text(
                      'No matching smart alternatives found.\nTry skipping the exercise.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: alternatives.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final alt = alternatives[index];
                      final equipmentText = alt.equipment?.join(', ') ?? 'Bodyweight';
                      final tags = [
                        if (alt.mechanic != null) alt.mechanic,
                        if (alt.force != null) alt.force,
                        if (alt.movementPattern != null) alt.movementPattern,
                      ].join(' • ');

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 8,
                        ),
                        title: Text(
                          alt.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Equipment: $equipmentText'),
                            if (tags.isNotEmpty)
                              Text(
                                tags,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            onSelectAlternative(alt);
                          },
                          child: const Text('Select'),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),

          // Skip Exercise Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.block),
              label: const Text(
                'Skip Exercise',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                onSkip();
              },
            ),
          ),
        ],
      ),
    );
  }
}
