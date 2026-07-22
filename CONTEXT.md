# Iron Heritage Domain

Core vocabulary for the Iron Heritage workout application, targeted at bodybuilders and serious gym-goers tracking hypertrophy.

## Language

**Routine**:
A multi-day training plan (e.g., Push-Pull-Legs) that defines the order of its planned training days.
_Avoid_: Program, schedule, workout

**Workout Template**:
A reusable prescription for one training day within a Routine. Starting it creates a Workout.
_Avoid_: Routine Day, planned Workout

**Workout**:
A single, specific training session executed on a given day.
_Avoid_: Session, routine

**Exercise**:
A specific physical movement performed during a workout (e.g., Bench Press, Pull-up).
_Avoid_: Movement, lift

**Set**:
A logged instance of an exercise containing reps, weight, an optional RIR, and a type classification (Working or Dropset). Warm-up sets are intentionally not logged.
_Avoid_: Round

**Reps**:
The number of times an exercise is continuously performed in a set.

**Weight**:
The resistance used in a set. For bodyweight/calisthenics, this represents additional added weight (0 or null means strictly bodyweight).
_Avoid_: Load, resistance

**Wger**:
The external, open-source API (wger.de) used to populate the local database with the exercise catalog, muscle groups, and equipment. Only English exercises are synced for the MVP.

**RIR**:
Reps in Reserve. An optional subjective metric of how many more reps could have been completed before failure in a set.
_Avoid_: RPE (Rate of Perceived Exertion)

**Occupied Exercise**:
An exercise the user cannot perform due to equipment unavailability. Triggers the Smart Alternatives algorithm.

**Smart Alternatives**:
A local deterministic algorithm that finds replacement exercises using target-muscle coverage plus `mechanic`, `force`, and `movementPattern` relevance. Candidates need target-muscle overlap and a Relevance Score of at least 65, then sort by equipment tier, descending score, and normalized exercise name.

**Relevance Score**:
A 0–100 Smart Alternatives product heuristic: target-muscle coverage contributes 60 points, matching `mechanic` 15, matching `force` 10, and matching `movementPattern` 15. Candidate primary-muscle matches receive full coverage credit; secondary-muscle matches receive half credit. It is not a scientifically validated equivalence measurement.

**Equipment Priority Chain**:
The first Smart Alternatives sort key. It begins at the Occupied Exercise's recognized core equipment, wraps through Barbell → Smith Machine → Cable → Machine → Dumbbell, and always leaves Bodyweight last.

**Mechanic**:
Classification of an exercise as either `Compound` (multi-joint) or `Isolation` (single-joint).

**Force**:
The direction of resistance applied during an exercise, categorized as `Push`, `Pull`, or `Static`.

**Movement Pattern**:
The specific kinesiological shape of the exercise (e.g., `Press`, `Fly`, `Row`, `Pulldown`, `Curl`, `Extension`, `Squat`, `Hinge`, `Raise`).
