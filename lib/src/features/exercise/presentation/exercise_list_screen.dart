import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';

final exercisesProvider = StreamProvider<List<Exercise>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.exercises).watch();
});

class ExerciseListScreen extends ConsumerWidget {
  const ExerciseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercisesAsync = ref.watch(exercisesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercises'),
      ),
      body: exercisesAsync.when(
        data: (exercises) {
          if (exercises.isEmpty) {
            return const Center(child: Text('No exercises found.'));
          }
          return ListView.builder(
            itemCount: exercises.length,
            itemBuilder: (context, index) {
              final ex = exercises[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ex.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text('Category: ${ex.category ?? "N/A"}'),
                      Text('Primary Muscles: ${ex.primaryMuscles?.join(", ") ?? "None"}'),
                      Text('Secondary: ${ex.secondaryMuscles?.join(", ") ?? "None"}'),
                      Text('Equipment: ${ex.equipment?.join(", ") ?? "None"}'),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
