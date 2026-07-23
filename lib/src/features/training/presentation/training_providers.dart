import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../data/drift_training_repository.dart';
import '../data/training_repository.dart';
import '../domain/training_models.dart';

enum TrainingContentType { templates, routines }

typedef TrainingListQuery = ({bool archived, String query});

final trainingRepositoryProvider = Provider<TrainingRepository>((ref) {
  return DriftTrainingRepository(ref.watch(databaseProvider));
});

final templateSummariesProvider = StreamProvider.autoDispose
    .family<List<WorkoutTemplateSummary>, TrainingListQuery>((ref, request) {
      return ref
          .watch(trainingRepositoryProvider)
          .watchTemplates(archived: request.archived, query: request.query);
    });

final routineSummariesProvider = StreamProvider.autoDispose
    .family<List<RoutineSummary>, TrainingListQuery>((ref, request) {
      return ref
          .watch(trainingRepositoryProvider)
          .watchRoutines(archived: request.archived, query: request.query);
    });
