# Training Screen Design

**Date:** 2026-07-23
**Status:** Approved in design interview
**Scope:** Training navigation, Workout Template library, Routine library, creation, editing, detail, archive, and copy behavior

## Objective

Give users one place to author reusable training content without coupling that work to scheduling. The screen must support users who only need standalone Workout Templates, such as `Chest/Back`, `Legs`, and `Arms`, as well as users who group ordered Template copies into Routines.

## Product boundaries

- The bottom-navigation destination is named **Training**.
- Training owns reusable Workout Templates and Routines.
- Calendar exclusively owns scheduling, cancellation, and rescheduling.
- Training displays no dates, scheduled state, or Calendar actions.
- There is no Active Routine concept.
- Starting a Workout from Template detail is allowed, but Workout tracking is a separate feature.
- Built-in, generated, and recommended Routines are outside this scope.

## Domain model

### Workout Template

A reusable prescription for one training day. It contains one or more ordered Exercise Prescriptions and may exist:

- standalone in the Templates library; or
- as a Routine-owned Template.

Standalone Template names are case-insensitively unique. Routine-owned Template names need only be unique inside their Routine.

### Exercise Prescription

An Exercise plus:

- one or more ordered Planned Sets;
- optional notes.

When an Exercise has been used before, adding it prefills an editable copy of its most recently saved Exercise Prescription, including Planned Sets and notes. This is a point-in-time copy, not a live link.

### Planned Set

A row containing:

- optional target Weight;
- optional repetition range;
- optional target RIR;
- type, defaulting to `Working`, optionally `Dropset`.

An Exercise Prescription requires at least one Planned Set, but every target field may remain blank. A first-time Exercise begins with one blank Planned Set.

### Routine

A reusable training plan containing one or more ordered Workout Templates.

Copy behavior is governed by [ADR 0004](../../adr/0004-workout-template-copy-semantics.md).

- Adding a standalone Template creates an independent Routine-owned copy.
- Editing either copy never updates the other.
- Creating a Template inside a Routine keeps it Routine-only.
- `Save copy to Templates` creates a new independent standalone copy.
- Removing a Routine-owned Template affects only that Routine.

Routine names are case-insensitively unique among non-archived Routines.

### Archive

Archiving removes an item from normal selection while preserving it, its completed Workout history, and restore capability.

- Archiving a standalone Template does not affect Routine-owned copies.
- Archiving a Routine retains its owned Templates.
- Archived items cannot be selected for future scheduling until restored.

## Information architecture

### Training destination

The initial selected tab is **Templates**. The screen contains:

1. App bar:
   - `Training` title;
   - search;
   - context-sensitive `+`;
   - overflow menu.
2. Top tabs:
   - `Templates`;
   - `Routines`.
3. Selected-tab content.

The selected tab, scroll position, and active search query survive navigation away from and back to Training during the current app session.

### Context-sensitive actions

| Selected tab | `+` action | Overflow archive action |
|---|---|---|
| Templates | Create standalone Template | Archived Templates |
| Routines | Create Routine | Archived Routines |

### Sorting and search

Both lists sort by most recently updated first.

Search applies only to the selected tab:

- Templates match Template names and contained Exercise names.
- Routines match Routine names and contained Template names.

An empty library and a search with no matches use distinct empty states.

## Templates tab

### List

Each Template item shows:

- name;
- Exercise count;
- short ordered Exercise-name preview.

Tapping an item opens read-first Template detail.

The empty state explains that Templates represent individual training days and points to the app-bar `+`.

### Template detail

Template detail displays the ordered prescription without entering edit mode. Actions:

- `Start Workout`;
- `Edit`;
- overflow → `Archive`.

Archived Template detail replaces Archive with Restore and does not offer Start Workout.

### Create and edit

Creation and editing use one scrollable editor:

- Template name;
- ordered Exercise Prescription rows;
- `Add exercise`;
- explicit app-bar `Save`.

Save is enabled only when:

- the trimmed name is non-empty;
- the standalone name is unique case-insensitively;
- at least one Exercise Prescription exists;
- every Exercise Prescription contains at least one Planned Set.

Planned Set target values may all be blank.

Attempting to leave with unsaved changes asks whether to discard them.

### Add exercise

`Add exercise` opens a full-screen Exercise catalog containing:

- search;
- muscle filter;
- equipment filter;
- exercise-type filter;
- multi-select rows;
- sticky `Add N exercises` action.

Selected Exercises append to the editor in selection order. The user can reorder them afterward.

For each added Exercise:

- if a prior saved Exercise Prescription exists anywhere in the local Training library, copy the most recently saved Planned Sets and notes;
- otherwise create one blank Planned Set.

### Prescription editing

Exercise rows support inline editing for:

- Planned Sets;
- notes;
- Exercise ordering.

Planned Sets support adding, removing, and reordering. Exercise ordering uses visible drag handles.

## Routines tab

### List

Each Routine item shows:

- name;
- Template count;
- short ordered Template-name preview.

Tapping an item opens read-first Routine detail.

The empty state explains that Routines are optional ordered groupings of training-day Templates and points to the app-bar `+`.

### Routine detail

Routine detail displays its ordered Template list. Actions:

- `Edit`;
- overflow → `Archive`.

Tapping a contained Template opens that Routine-owned Template detail, where the user can:

- start a Workout;
- edit the Routine-owned copy;
- `Save copy to Templates`.

There is no `Start Routine` action because the product has no Active Routine or implicit next-Template state.

### Create and edit

Creation and editing use one scrollable editor:

- Routine name;
- ordered Template rows;
- `Add template`;
- explicit app-bar `Save`.

Save is enabled only when:

- the trimmed Routine name is non-empty;
- the name is unique case-insensitively among non-archived Routines;
- at least one Template exists;
- Template names are unique case-insensitively inside the Routine.

Attempting to leave with unsaved changes asks whether to discard them.

Templates use visible drag handles for ordering. Removing a Template from the draft only changes that Routine; completed Workout history remains available.

### Add template

`Add template` opens a sheet with:

- multi-select standalone Templates;
- `Create new`.

Confirming selected standalone Templates creates independent Routine-owned copies. `Create new` opens the Template editor in Routine-owned mode and returns the completed Template to the Routine draft.

## State and data behavior

### Drafts and persistence

- Editors hold draft state until explicit Save.
- Save validates and persists the complete aggregate atomically.
- A failed Save leaves the draft intact and presents a retryable error.
- Leaving without changes needs no confirmation.

### Identity during copy

Copying a Template generates new identities for:

- Template;
- Exercise Prescriptions;
- Planned Sets.

The underlying Exercise catalog identities remain shared. Copying does not create duplicate catalog Exercises.

### Loading and failure states

- Initial list loading uses skeleton rows.
- Local storage or Exercise catalog failure shows a clear reason and Retry action.
- Search/filter failures preserve the query and selections.
- No destructive action occurs until the user confirms it.

## Accessibility

- Interactive targets meet at least 48×48 logical pixels.
- Tabs, app-bar icons, cards, drag handles, and set controls have semantic labels.
- Counts are announced with meaningful nouns.
- Drag-reorder controls also expose move-up and move-down semantic actions.
- Validation is attached to the relevant field and summarized for screen-reader focus after failed Save.
- Color never carries state alone.

## Verification

Widget and domain tests must cover:

1. Templates is the initial Training tab.
2. The app-bar `+` creates the selected tab's item type.
3. Tab, search, and scroll state survive navigation during the app session.
4. Template and Routine cards render their approved summaries.
5. Search matches both top-level and contained names.
6. Template validation permits blank Planned Set targets but rejects missing set rows.
7. Duplicate-name rules use case-insensitive comparison at the correct scope.
8. Exercise reuse copies the latest prescription without linking future edits.
9. Adding standalone Templates to a Routine deep-copies owned content.
10. Routine-owned edits do not mutate standalone Templates, and vice versa.
11. `Save copy to Templates` produces another independent deep copy.
12. Drag ordering persists for Exercises, Planned Sets, and Routine Templates.
13. Archive and restore preserve data and isolate independent copies.
14. Unsaved-change confirmation protects drafts.
15. Storage failures retain edits and allow retry.
16. Training exposes no Calendar state or scheduling actions.

## Deferred work

- Calendar scheduling and cancellation
- Routine progression or Active Routine
- Workout tracker implementation
- Template duplication outside Routine copy flows
- Built-in or generated training plans
- Cloud synchronization and conflict resolution
