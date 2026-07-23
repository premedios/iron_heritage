# ADR 0004: Copy Workout Templates into Routines

**Status:** Accepted
**Date:** 2026-07-23

## Context

Workout Templates are first-class training-day prescriptions and may exist without a Routine. A user may also assemble ordered copies of Templates into a Routine.

The product needs predictable edit behavior when the same starting Template appears standalone and inside one or more Routines. Live references would make a single edit propagate across every containing Routine. That coupling is undesirable because each Routine may need its own variation of the training day.

## Decision

Routine-owned Workout Templates are independent copies:

- Adding a standalone Template to a Routine deep-copies the Template, Exercise Prescriptions, Planned Sets, and notes.
- Exercise catalog identities remain shared references.
- Editing a standalone Template never changes Routine-owned copies.
- Editing a Routine-owned Template never changes its source or copies in other Routines.
- A Template created inside a Routine remains Routine-only.
- `Save copy to Templates` deep-copies a Routine-owned Template into the standalone library.
- No copy retains a live synchronization relationship with its source.

## Consequences

### Positive

- Routine-specific edits are safe and unsurprising.
- Standalone Templates remain reusable starting points.
- The model does not require propagation rules, conflict prompts, or synchronization state.
- Archiving one copy cannot unexpectedly affect another.

### Negative

- Similar Templates can drift without warning.
- Improvements must be repeated manually across copies.
- Deep-copy logic and copy-isolation tests are required.
- Storage contains duplicated prescription data.

## Rejected alternatives

### Live shared Templates

Every Routine would reference the standalone Template. This minimizes duplication but makes edits propagate to unrelated Routines.

### Ask on every edit

The editor would ask whether to update one copy or all related copies. This introduces persistent source relationships, branching rules, and repeated decision overhead.
