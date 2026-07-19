# 2. Feature-First Directory Structure

Date: 2026-07-19

## Status

Accepted

## Context

As the Iron Heritage app grows to encompass multiple screens, models, and Riverpod providers, we need a scalable way to organize the codebase. Traditional "layer-first" architectures (grouping all models together, all screens together) make it difficult to locate related code when working on a specific feature, especially when using Riverpod.

## Decision

We will adopt a **Feature-First Architecture** for the `lib/` directory.
Code will be grouped by its functional domain (e.g., `workout`, `routine`, `settings`) rather than its technical layer.

The structure within each feature will follow a standard separation of concerns:
```
lib/
└── src/
    ├── features/
    │   └── workout/
    │       ├── data/          # Repositories, Drift queries, DTOs
    │       ├── domain/        # Core models, entities
    │       └── presentation/  # Widgets, screens, Riverpod controllers
    └── core/                  # Shared utilities, app-wide widgets, routing
```

## Consequences

- **Pros**: Highly scalable. When building or modifying a feature, all relevant files (UI, state, data) are co-located. Aligns perfectly with Riverpod best practices.
- **Cons**: Requires discipline to identify the correct "feature" boundary. Shared components must be explicitly placed in `core/` to avoid circular dependencies between features.
