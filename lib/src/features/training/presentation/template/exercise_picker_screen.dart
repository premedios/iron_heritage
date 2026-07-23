import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database.dart';
import '../../../exercise/presentation/exercise_list_screen.dart';
import '../../domain/training_models.dart';

final class ExercisePickerScreen extends ConsumerStatefulWidget {
  const ExercisePickerScreen({required this.initiallySelectedIds, super.key});

  final Set<int> initiallySelectedIds;

  @override
  ConsumerState<ExercisePickerScreen> createState() =>
      _ExercisePickerScreenState();
}

final class _ExercisePickerScreenState
    extends ConsumerState<ExercisePickerScreen> {
  late final List<int> _selectedIds;
  String _query = '';
  String? _muscle;
  String? _equipment;
  String? _type;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.initiallySelectedIds.toList();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(exercisesProvider);
    final catalogIds = catalog.hasValue
        ? catalog.requireValue.map((exercise) => exercise.id).toSet()
        : null;
    final selectedIds = catalogIds == null
        ? _selectedIds
        : _selectedIds.where(catalogIds.contains).toList();
    if (catalogIds != null && selectedIds.length != _selectedIds.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final currentCatalog = ref.read(exercisesProvider);
        if (!currentCatalog.hasValue) {
          return;
        }
        final currentIds = currentCatalog.requireValue
            .map((exercise) => exercise.id)
            .toSet();
        setState(
          () => _selectedIds.removeWhere((id) => !currentIds.contains(id)),
        );
      });
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Add exercises')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              hintText: 'Search exercises',
              leading: const Icon(Icons.search),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: catalog.when(
              data: _buildCatalog,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _CatalogError(
                error: error,
                onRetry: () => ref.invalidate(exercisesProvider),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: selectedIds.isEmpty || !catalog.hasValue
              ? null
              : () {
                  final exercises = catalog.requireValue;
                  final byId = {
                    for (final exercise in exercises) exercise.id: exercise,
                  };
                  final choices = [
                    for (final id in selectedIds)
                      if (byId[id] case final exercise?)
                        ExerciseChoice(id: id, name: exercise.name),
                  ];
                  Navigator.pop(context, choices);
                },
          child: Text(
            'Add ${selectedIds.length} '
            '${selectedIds.length == 1 ? 'exercise' : 'exercises'}',
          ),
        ),
      ),
    );
  }

  Widget _buildCatalog(List<Exercise> exercises) {
    final muscles = _sortedValues(
      exercises.expand(
        (exercise) => [?exercise.category, ...?exercise.primaryMuscles],
      ),
    );
    final equipment = _sortedValues(
      exercises.expand((exercise) => exercise.equipment ?? const []),
    );
    final types = _sortedValues(
      exercises.map((exercise) => exercise.mechanic).whereType<String>(),
    );
    final normalizedQuery = _query.trim().toLowerCase();
    final visible = exercises.where((exercise) {
      final exerciseMuscles = <String>{
        ?exercise.category,
        ...?exercise.primaryMuscles,
      };
      return exercise.name.toLowerCase().contains(normalizedQuery) &&
          (_muscle == null || exerciseMuscles.contains(_muscle)) &&
          (_equipment == null ||
              (exercise.equipment ?? const []).contains(_equipment)) &&
          (_type == null || exercise.mechanic == _type);
    }).toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FilterGroup(
                  semanticLabel: 'Muscle filters',
                  values: muscles,
                  selected: _muscle,
                  onSelected: (value) =>
                      setState(() => _muscle = _muscle == value ? null : value),
                ),
                _FilterGroup(
                  semanticLabel: 'Equipment filters',
                  values: equipment,
                  selected: _equipment,
                  onSelected: (value) => setState(
                    () => _equipment = _equipment == value ? null : value,
                  ),
                ),
                _FilterGroup(
                  semanticLabel: 'Exercise type filters',
                  values: types,
                  selected: _type,
                  onSelected: (value) =>
                      setState(() => _type = _type == value ? null : value),
                ),
              ],
            ),
          ),
        ),
        if (visible.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('No exercises match these filters')),
          )
        else
          SliverList.builder(
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final exercise = visible[index];
              final selected = _selectedIds.contains(exercise.id);
              return CheckboxListTile(
                key: ValueKey('exercise-choice-${exercise.id}'),
                value: selected,
                title: Text(exercise.name),
                subtitle: Text(
                  [
                    ?exercise.category,
                    ...?exercise.equipment,
                    ?exercise.mechanic,
                  ].join(' • '),
                ),
                onChanged: (_) => _toggle(exercise.id),
                controlAffinity: ListTileControlAffinity.leading,
              );
            },
          ),
      ],
    );
  }

  void _toggle(int id) {
    setState(() {
      if (_selectedIds.remove(id)) {
        return;
      }
      _selectedIds.add(id);
    });
  }

  static List<String> _sortedValues(Iterable<String> values) {
    return values.where((value) => value.trim().isNotEmpty).toSet().toList()
      ..sort(
        (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
      );
  }
}

final class _FilterGroup extends StatelessWidget {
  const _FilterGroup({
    required this.semanticLabel,
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  final String semanticLabel;
  final List<String> values;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const SizedBox.shrink();
    }
    return Semantics(
      label: semanticLabel,
      container: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final value in values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(value),
                  selected: selected == value,
                  onSelected: (_) => onSelected(value),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

final class _CatalogError extends StatelessWidget {
  const _CatalogError({required this.error, required this.onRetry});

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
            const Icon(Icons.error_outline),
            const SizedBox(height: 8),
            Text('Could not load exercises: $error'),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
