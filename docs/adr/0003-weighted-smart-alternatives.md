# 3. Weighted Smart Alternatives Relevance

Date: 2026-07-21

## Status

Accepted

## Context

ADR-0002 required exact primary-muscle, mechanic, force, and movement-pattern
matches. That rejected useful substitutions when metadata differed despite
substantial target-muscle overlap, including Barbell Squat to Leg Press.

## Decision

Smart Alternatives uses deterministic weighted relevance scoring:

- Target-muscle coverage contributes 60 points. Each occupied primary muscle
  earns full credit when it is a candidate primary muscle and half credit when
  it is a candidate secondary muscle.
- Matching mechanic contributes 15 points.
- Matching force contributes 10 points.
- Matching movement pattern contributes 15 points.
- Candidates require at least one target-muscle overlap and a score of at least
  65.
- Compared strings are trimmed and lowercased. Missing metadata contributes
  zero, and an occupied exercise without primary muscles has no alternatives.
- Candidates are deduplicated by normalized name. The occupied exercise is
  excluded by ID or normalized name.
- Equipment tier remains the first sort key. Relevance score descending is the
  second key and normalized exercise name is the final key.
- Leg Press remains classified as `Press`; no schema or seed-data change is
  needed.

The numeric weights and threshold are product heuristics. They do not claim
scientifically validated exercise equivalence.

## Consequences

- High-confidence substitutions can cross movement-pattern boundaries.
- Exact matches still score highest when target-muscle coverage is equal.
- Equipment practicality remains more important than relevance differences
  between tiers.
- Recommendations remain deterministic and conservative, but training-goal
  specificity and exercise-specific strength transfer remain out of scope.
