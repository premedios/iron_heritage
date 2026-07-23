import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/training_models.dart';
import 'archived_training_screen.dart';
import 'training_providers.dart';
import 'widgets/training_list_cards.dart';
import 'widgets/training_list_state.dart';

class TrainingScreen extends ConsumerStatefulWidget {
  const TrainingScreen({
    super.key,
    required this.onCreateTemplate,
    required this.onCreateRoutine,
    required this.onOpenTemplate,
    required this.onOpenRoutine,
  });

  final VoidCallback onCreateTemplate;
  final VoidCallback onCreateRoutine;
  final ValueChanged<int> onOpenTemplate;
  final ValueChanged<int> onOpenRoutine;

  @override
  ConsumerState<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends ConsumerState<TrainingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _searchController;
  var _selectedIndex = 0;
  var _searchVisible = false;

  TrainingContentType get _selectedContentType => _selectedIndex == 0
      ? TrainingContentType.templates
      : TrainingContentType.routines;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, initialIndex: 0, vsync: this)
      ..addListener(_handleTabSelection);
    _searchController = TextEditingController();
  }

  void _handleTabSelection() {
    if (_selectedIndex == _tabController.index) {
      return;
    }
    setState(() => _selectedIndex = _tabController.index);
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabSelection)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final creatingTemplate =
        _selectedContentType == TrainingContentType.templates;
    final searchActionLabel = _searchVisible
        ? 'Close Search'
        : 'Search Training';
    return Scaffold(
      appBar: AppBar(
        title: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Opacity(
              opacity: _searchVisible ? 0 : 1,
              child: ExcludeSemantics(
                excluding: _searchVisible,
                child: const Text('Training'),
              ),
            ),
            Opacity(
              opacity: _searchVisible ? 1 : 0,
              child: IgnorePointer(
                ignoring: !_searchVisible,
                child: ExcludeSemantics(
                  excluding: !_searchVisible,
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search Training',
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          Semantics(
            label: searchActionLabel,
            button: true,
            excludeSemantics: true,
            onTap: () => setState(() => _searchVisible = !_searchVisible),
            child: IconButton(
              tooltip: searchActionLabel,
              onPressed: () => setState(() => _searchVisible = !_searchVisible),
              icon: Icon(_searchVisible ? Icons.close : Icons.search),
            ),
          ),
          IconButton(
            tooltip: creatingTemplate ? 'Create Template' : 'Create Routine',
            onPressed: creatingTemplate
                ? widget.onCreateTemplate
                : widget.onCreateRoutine,
            icon: const Icon(Icons.add),
          ),
          PopupMenuButton<TrainingContentType>(
            tooltip: 'More Training actions',
            onSelected: (contentType) {
              Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => ArchivedTrainingScreen(
                    contentType: contentType,
                    onOpenTemplate: widget.onOpenTemplate,
                  ),
                ),
              );
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _selectedContentType,
                child: Text(
                  creatingTemplate ? 'Archived Templates' : 'Archived Routines',
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Templates'),
            Tab(text: 'Routines'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _TemplateList(
            query: _searchController.text,
            onOpen: widget.onOpenTemplate,
          ),
          _RoutineList(
            query: _searchController.text,
            onOpen: widget.onOpenRoutine,
          ),
        ],
      ),
    );
  }
}

class _TemplateList extends ConsumerWidget {
  const _TemplateList({required this.query, required this.onOpen});

  final String query;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = (archived: false, query: query);
    final summaries = ref.watch(templateSummariesProvider(request));
    if (query.trim().isNotEmpty && summaries.isLoading) {
      final unfiltered = ref.watch(
        templateSummariesProvider((archived: false, query: '')),
      );
      return unfiltered.when(
        data: (items) => _buildData(items.where(_matchesQuery).toList()),
        loading: () => const TrainingListSkeleton(keyPrefix: 'template'),
        error: (error, _) => TrainingListError(
          error: error,
          onRetry: () => ref.invalidate(templateSummariesProvider(request)),
        ),
      );
    }
    return summaries.when(
      data: _buildData,
      loading: () => const TrainingListSkeleton(keyPrefix: 'template'),
      error: (error, _) => TrainingListError(
        error: error,
        onRetry: () => ref.invalidate(templateSummariesProvider(request)),
      ),
    );
  }

  Widget _buildData(List<WorkoutTemplateSummary> items) {
    if (items.isEmpty) {
      return TrainingListEmpty(
        contentType: TrainingContentType.templates,
        query: query,
      );
    }
    return ListView.separated(
      key: const PageStorageKey<String>('training-template-list'),
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final item = items[index];
        return WorkoutTemplateCard(summary: item, onTap: () => onOpen(item.id));
      },
    );
  }

  bool _matchesQuery(WorkoutTemplateSummary summary) {
    final normalized = query.trim().toLowerCase();
    return summary.name.toLowerCase().contains(normalized) ||
        summary.exerciseNames.any(
          (name) => name.toLowerCase().contains(normalized),
        );
  }
}

class _RoutineList extends ConsumerWidget {
  const _RoutineList({required this.query, required this.onOpen});

  final String query;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = (archived: false, query: query);
    final summaries = ref.watch(routineSummariesProvider(request));
    if (query.trim().isNotEmpty && summaries.isLoading) {
      final unfiltered = ref.watch(
        routineSummariesProvider((archived: false, query: '')),
      );
      return unfiltered.when(
        data: (items) => _buildData(items.where(_matchesQuery).toList()),
        loading: () => const TrainingListSkeleton(keyPrefix: 'routine'),
        error: (error, _) => TrainingListError(
          error: error,
          onRetry: () => ref.invalidate(routineSummariesProvider(request)),
        ),
      );
    }
    return summaries.when(
      data: _buildData,
      loading: () => const TrainingListSkeleton(keyPrefix: 'routine'),
      error: (error, _) => TrainingListError(
        error: error,
        onRetry: () => ref.invalidate(routineSummariesProvider(request)),
      ),
    );
  }

  Widget _buildData(List<RoutineSummary> items) {
    if (items.isEmpty) {
      return TrainingListEmpty(
        contentType: TrainingContentType.routines,
        query: query,
      );
    }
    return ListView.separated(
      key: const PageStorageKey<String>('training-routine-list'),
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final item = items[index];
        return RoutineCard(summary: item, onTap: () => onOpen(item.id));
      },
    );
  }

  bool _matchesQuery(RoutineSummary summary) {
    final normalized = query.trim().toLowerCase();
    return summary.name.toLowerCase().contains(normalized) ||
        summary.templateNames.any(
          (name) => name.toLowerCase().contains(normalized),
        );
  }
}
