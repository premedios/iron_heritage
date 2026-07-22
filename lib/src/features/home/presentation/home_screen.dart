import 'package:flutter/material.dart';

import 'home_view_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.state,
    required this.today,
    required this.onAction,
    super.key,
  });

  final HomeViewState state;
  final DateTime today;
  final ValueChanged<HomeAction> onAction;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _promptedMissedWorkout;

  @override
  Widget build(BuildContext context) {
    _queueMissedWorkoutPrompt(context, widget.state.hero);

    return Scaffold(
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          final action = switch (index) {
            0 => HomeAction.openHome,
            1 => HomeAction.openRoutines,
            _ => HomeAction.openCalendar,
          };
          widget.onAction(action);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center),
            label: 'Routines',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TODAY',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      Text(_formattedDate(widget.today)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Settings',
                  onPressed: () => widget.onAction(HomeAction.openSettings),
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (!widget.state.isLoading &&
                widget.state.errorMessage != null) ...[
              _buildErrorBanner(context, widget.state.errorMessage!),
              const SizedBox(height: 16),
            ],
            if (widget.state.isLoading)
              _buildLoadingState(context)
            else ...[
              _buildHero(context, widget.state.hero),
              const SizedBox(height: 24),
              _buildLastWorkout(context, widget.state.lastWorkout),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context, String message) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.errorContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: colors.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
            TextButton(
              onPressed: () => widget.onAction(HomeAction.retry),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final skeletonColor = Theme.of(context).colorScheme.onSurface.withAlpha(20);
    return Semantics(
      label: 'Loading Home',
      child: ExcludeSemantics(
        child: Column(
          children: [
            Card(
              child: SizedBox(
                height: 248,
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: skeletonColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: SizedBox(
                height: 132,
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: skeletonColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLastWorkout(BuildContext context, LastWorkoutSummary? summary) {
    if (summary == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('LAST WORKOUT'),
              SizedBox(height: 8),
              Text('Your first completed workout will appear here.'),
            ],
          ),
        ),
      );
    }

    return Card(
      child: InkWell(
        onTap: () => widget.onAction(HomeAction.openLastWorkout),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('LAST WORKOUT'),
              const SizedBox(height: 8),
              Text(
                summary.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  Text('${summary.duration.inMinutes} min'),
                  Text('${_formattedInteger(summary.volumeKilograms)} kg'),
                  if (summary.improvementPercent != null)
                    Text(
                      '${summary.improvementPercent! >= 0 ? '+' : ''}'
                      '${summary.improvementPercent!.toStringAsFixed(1)}% '
                      'vs previous',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context, HomeHeroState hero) {
    return switch (hero) {
      ActiveWorkoutHomeHero() => _activeWorkoutHero(context, hero),
      MissedWorkoutHomeHero() => _missedWorkoutHero(context, hero),
      NoRoutineHomeHero() => _noRoutineHero(context),
      RestDayHomeHero() => _restDayHero(context, hero),
      ScheduledWorkoutHomeHero() => _scheduledWorkoutHero(context, hero),
    };
  }

  Widget _noRoutineHero(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Build your routine',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose a plan for your training days, or start freely.',
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => widget.onAction(HomeAction.chooseRoutine),
                child: const Text('Create or Choose Routine'),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: () => widget.onAction(HomeAction.startEmptyWorkout),
                child: const Text('Start Empty Workout'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _restDayHero(BuildContext context, RestDayHomeHero hero) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recovery day'),
            const SizedBox(height: 8),
            Text(
              'Next: ${hero.nextTemplateName}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(_formattedDate(hero.nextWorkoutDate)),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => widget.onAction(HomeAction.startEarly),
              child: const Text('Start Early'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _missedWorkoutHero(BuildContext context, MissedWorkoutHomeHero hero) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Missed workout'),
            const SizedBox(height: 8),
            Text(
              hero.templateName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(hero.routineName.toUpperCase()),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showMissedWorkoutSheet(context),
                child: const Text('Review options'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activeWorkoutHero(BuildContext context, ActiveWorkoutHomeHero hero) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Workout in progress'),
            const SizedBox(height: 8),
            Text(
              hero.workoutName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text('${_formattedElapsed(hero.elapsed)} elapsed'),
            Text(
              '${hero.completedExercises} of ${hero.totalExercises} exercises',
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => widget.onAction(HomeAction.resumeWorkout),
                child: const Text('Resume Workout'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scheduledWorkoutHero(
    BuildContext context,
    ScheduledWorkoutHomeHero hero,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(hero.routineName.toUpperCase()),
            const SizedBox(height: 8),
            Text(
              hero.templateName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text('${hero.exerciseCount} exercises'),
            Text('${hero.estimatedDuration.inMinutes} min'),
            Text(hero.targetMuscleGroups.join(' • ')),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () =>
                    widget.onAction(HomeAction.startScheduledWorkout),
                child: const Text('Start Workout'),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: () => widget.onAction(HomeAction.startEmptyWorkout),
                child: const Text('Start Empty Workout'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formattedElapsed(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _formattedInteger(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      final remaining = digits.length - index;
      buffer.write(digits[index]);
      if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
    }
    return buffer.toString();
  }

  void _queueMissedWorkoutPrompt(BuildContext context, HomeHeroState hero) {
    if (hero is! MissedWorkoutHomeHero) return;

    final promptKey =
        '${hero.templateName}-${hero.scheduledDate.toIso8601String()}';
    if (_promptedMissedWorkout == promptKey) return;
    _promptedMissedWorkout = promptKey;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showMissedWorkoutSheet(context);
    });
  }

  Future<void> _showMissedWorkoutSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Resolve missed workout',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(sheetContext);
                widget.onAction(HomeAction.startMissedWorkout);
              },
              child: const Text('Start now'),
            ),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(sheetContext);
                widget.onAction(HomeAction.rescheduleMissedWorkout);
              },
              child: const Text('Reschedule'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(sheetContext);
                widget.onAction(HomeAction.skipMissedWorkout);
              },
              child: const Text('Skip'),
            ),
          ],
        ),
      ),
    );
  }

  String _formattedDate(DateTime date) {
    const months = [
      'JANUARY',
      'FEBRUARY',
      'MARCH',
      'APRIL',
      'MAY',
      'JUNE',
      'JULY',
      'AUGUST',
      'SEPTEMBER',
      'OCTOBER',
      'NOVEMBER',
      'DECEMBER',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}
