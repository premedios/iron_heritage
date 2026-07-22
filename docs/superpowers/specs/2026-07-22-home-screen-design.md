# Home Screen Design

**Date:** 2026-07-22
**Status:** Approved
**Scope:** Iron Heritage mobile Home screen

## Goal

Make starting or resuming today's training the unmistakable primary action. Show one useful progress signal without turning Home into an analytics dashboard.

## Design principles

- Session first: current training intent outranks history and navigation.
- One dominant action per state.
- Serious, calm tone: no guilt streaks, celebratory clutter, or fake urgency.
- Progressive disclosure: detailed exercises and analytics live beyond Home.
- State must be explicit through text, not color alone.

## Information architecture

Home is one vertically scrolling screen:

1. Header
2. State-driven hero
3. Last Workout summary
4. Bottom navigation

The header contains `TODAY`, the local date, and a profile/settings action. Bottom navigation contains Home, Routines, and Calendar.

## Hero state priority

Only the highest-priority applicable state appears:

1. **Active Workout** — Resume the workout in progress.
2. **Missed Workout Template** — Resolve the missed schedule.
3. **Scheduled Workout Template** — Start today's planned training.
4. **Rest Day** — Show recovery context and the next scheduled session.
5. **No Routine** — Create or choose a Routine.

### Active Workout

The hero states `Workout in progress` and shows elapsed time plus exercise progress. `Resume Workout` is the dominant action. Reopening the app lands on Home; it does not force navigation into the workout.

### Missed Workout Template

Opening Home immediately presents a bottom sheet with three explicit actions:

- `Start now`
- `Reschedule`
- `Skip`

Dismissal must not silently alter the schedule.

### Scheduled Workout Template

Use the approved focused-card layout. Show:

- Routine name as an eyebrow label
- Workout Template name
- Exercise count
- Estimated duration
- Target muscle groups
- Primary `Start Workout` action
- Secondary `Start Empty Workout` text action

Do not preview individual exercises on Home.

### Rest Day

Use a recovery-focused card showing the next Workout Template and date. `Start Early` is secondary; the screen must not imply the user failed to train.

### No Routine

The primary action is `Create or Choose Routine`. `Start Empty Workout` remains secondary so training is never blocked by setup.

## Last Workout summary

Show one compact progress signal below the hero:

- Duration
- Total volume
- Improvement versus the comparable previous workout, when available

Tapping the summary opens Workout details. If no history exists, use neutral, encouraging copy and show no fabricated values.

## Visual direction

- Background: `#121415`
- Surface: charcoal, based on existing `#1E2022`
- Accent: Forge Red `#C8102E`, reserved for the primary action and important status
- Display type: Bebas Neue
- Body and metadata: Inter
- Spacious layout, restrained borders, minimal shadows
- Hero stays first and fully understandable on small screens

## Interaction and accessibility

- Interactive targets are at least 48 logical pixels.
- Support dynamic text without clipping critical actions.
- Provide semantic labels for icons, progress, dates, and metrics.
- Never communicate state using color alone.
- Maintain readable contrast for text and disabled states.
- Use loading skeletons that preserve final layout.
- Show failures inline with a clear retry action; retain any still-valid local data.

## Domain language

- **Routine:** Multi-day training plan defining the order of planned training days.
- **Workout Template:** Reusable prescription for one training day within a Routine. Starting it creates a Workout.
- **Workout:** A performed or in-progress training session.

Avoid `Routine Day` and `planned Workout` because they blur plan, prescription, and performed session.

## Data requirements

The presentation model must expose enough state to select exactly one hero:

- Active Workout and progress
- Today's scheduled Workout Template
- Missed scheduled Workout Template
- Current Routine
- Whether today is a rest day
- Next scheduled Workout Template and date
- Last completed Workout summary
- Loading and recoverable failure states

Scheduling is calendar-based, not automatic Routine rotation.

## Acceptance criteria

- Home always exposes a viable training action.
- Active Workout always outranks scheduled content.
- Scheduled hero matches the focused-card content list.
- Missed schedule requires an explicit user decision.
- Rest day and empty states remain neutral and non-punitive.
- Exactly one Last Workout progress summary appears below the hero.
- The screen uses existing Forge theme tokens and planned bottom navigation.
- Layout remains operable with large text and 48-pixel targets.

## Out of scope

- Exercise-level preview inside the Home hero
- Dense charts or multi-metric dashboards
- Streak mechanics
- Workout execution UI
- Routine builder UI
- Calendar UI
