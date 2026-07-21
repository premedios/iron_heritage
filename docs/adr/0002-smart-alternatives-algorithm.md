# 2. Smart Alternatives Algorithm & Priority Chain

Date: 2026-07-19

## Status

Superseded by [ADR-0003](0003-weighted-smart-alternatives.md)

## Context

Gym equipment is frequently occupied, forcing users to substitute exercises on the fly. To ensure users don't break the intent of their routine, we need a deterministic algorithm to recommend alternatives that target the same muscles using available equipment.

## Decision

We will implement a local query algorithm ("Smart Alternatives") with the following rules:

1. **Trigger**: The user marks an active exercise as "Occupied".
2. **Strict Biomechanical Match**: Alternatives MUST share the exact same `primaryMuscles`, `mechanic` (Compound/Isolation), `force` (Push/Pull/Static), AND `movementPattern` (Press/Fly/Row/etc.) as the occupied exercise. Secondary muscles are ignored for this match to maintain workout purity.
3. **Equipment Priority Chain**: The algorithm sorts available alternatives using a strict equipment priority wrap-around:
   - First, prioritize the *exact same equipment* as the occupied exercise (e.g., if you have dumbbells, look for another dumbbell exercise).
   - If not found, jump to the top of the global priority chain: **Barbell → Smith Machine → Cable → Machine → Dumbbell → Bodyweight** (absolute last resort).
4. **Presentation**: Unique viable results are displayed in a bottom sheet UI.
5. **Skip Fallback**: The bottom sheet includes a manual "Skip Exercise" button. If the user rejects all alternatives (or if the algorithm yields 0 results), the exercise is marked as `isSkipped = true` in the `WorkoutSets` table and omitted from the active workout log.

## Consequences

- **Pros**: Keeps workouts focused strictly on the intended primary muscles. Highly predictable and deterministic behavior. Prevents the user from accidentally selecting a half-measure exercise.
- **Cons**: Might return 0 results if the local database lacks exercises for a specific obscure muscle, resulting in a skipped exercise rather than a loose secondary-muscle fallback.
