sealed class HomeHeroState {
  const HomeHeroState();
}

class ActiveWorkoutHomeHero extends HomeHeroState {
  const ActiveWorkoutHomeHero({
    required this.workoutName,
    required this.elapsed,
    required this.completedExercises,
    required this.totalExercises,
  });

  final String workoutName;
  final Duration elapsed;
  final int completedExercises;
  final int totalExercises;
}

class MissedWorkoutHomeHero extends HomeHeroState {
  const MissedWorkoutHomeHero({
    required this.routineName,
    required this.templateName,
    required this.scheduledDate,
  });

  final String routineName;
  final String templateName;
  final DateTime scheduledDate;
}

class RestDayHomeHero extends HomeHeroState {
  const RestDayHomeHero({
    required this.nextTemplateName,
    required this.nextWorkoutDate,
  });

  final String nextTemplateName;
  final DateTime nextWorkoutDate;
}

class NoRoutineHomeHero extends HomeHeroState {
  const NoRoutineHomeHero();
}

class ScheduledWorkoutHomeHero extends HomeHeroState {
  const ScheduledWorkoutHomeHero({
    required this.routineName,
    required this.templateName,
    required this.exerciseCount,
    required this.estimatedDuration,
    required this.targetMuscleGroups,
  });

  final String routineName;
  final String templateName;
  final int exerciseCount;
  final Duration estimatedDuration;
  final List<String> targetMuscleGroups;
}

class LastWorkoutSummary {
  const LastWorkoutSummary({
    required this.name,
    required this.duration,
    required this.volumeKilograms,
    this.improvementPercent,
  });

  final String name;
  final Duration duration;
  final int volumeKilograms;
  final double? improvementPercent;
}

class HomeViewState {
  const HomeViewState({
    required this.hero,
    this.lastWorkout,
    this.isLoading = false,
    this.errorMessage,
  });

  const HomeViewState.loading()
    : hero = const NoRoutineHomeHero(),
      lastWorkout = null,
      isLoading = true,
      errorMessage = null;

  factory HomeViewState.resolve({
    ActiveWorkoutHomeHero? activeWorkout,
    MissedWorkoutHomeHero? missedWorkout,
    ScheduledWorkoutHomeHero? scheduledWorkout,
    RestDayHomeHero? restDay,
    LastWorkoutSummary? lastWorkout,
    String? errorMessage,
  }) {
    final hero =
        activeWorkout ??
        missedWorkout ??
        scheduledWorkout ??
        restDay ??
        const NoRoutineHomeHero();

    return HomeViewState(
      hero: hero,
      lastWorkout: lastWorkout,
      errorMessage: errorMessage,
    );
  }

  final HomeHeroState hero;
  final LastWorkoutSummary? lastWorkout;
  final bool isLoading;
  final String? errorMessage;
}

enum HomeAction {
  chooseRoutine,
  openCalendar,
  openHome,
  openLastWorkout,
  openRoutines,
  openSettings,
  retry,
  resumeWorkout,
  startMissedWorkout,
  rescheduleMissedWorkout,
  skipMissedWorkout,
  startEmptyWorkout,
  startEarly,
  startScheduledWorkout,
}
