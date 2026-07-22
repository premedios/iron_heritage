# 1. Local-First Architecture with Native Cloud Backup

Date: 2026-07-19

## Status

Accepted

## Context

Iron Heritage is a workout tracking app. Gyms often have poor internet connectivity, so the app must function perfectly offline without any loading spinners. However, users need their workout history backed up so it is not lost if they lose their device. We needed to choose between a dedicated remote backend (e.g., Firebase, Supabase) and a local-first approach.

## Decision

We will use a **Local-First Architecture**.
- **State Management**: Riverpod with manual providers. Generated-provider guidance is superseded by ADR-0003.
- **Persistence**: Drift (SQLite) for robust, relational, type-safe local data storage.
- **Sync/Backup**: We will not use a centralized backend. Instead, we will rely on first-party native cloud sync (Apple iCloud for iOS, and Google Drive / Android Auto Backup for Android) to backup the local Drift database.

## Consequences

- **Pros**: Zero backend hosting costs, perfect offline experience, and complete user data privacy (data lives in their own personal cloud account).
- **Cons**: Real-time social features are impossible. Cross-platform sync (e.g., syncing from an iPhone to an Android tablet) will be very difficult, as iCloud and Google Drive do not natively share app data containers.
