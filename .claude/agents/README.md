# Project subagents

Five agents vendored from [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents)
(MIT), scoped to this project rather than `~/.claude/agents/` so their behavior
is reviewable in diffs and travels with the repo.

## Local modifications

Each file has `tools:` and `model:` added to its frontmatter. **Upstream ships
neither**, which means an unmodified agent inherits the full toolset — `Write`,
`Bash`, and every MCP tool loaded in the session — regardless of how narrow its
job is.

| Agent | `tools:` | `model:` | Why |
|---|---|---|---|
| `engineering-mobile-app-builder` | `Read, Write, Edit, Glob, Grep, Bash` | `opus` | The only agent that authors Dart. Needs `Write` for new widgets/screens, `Bash` for `flutter analyze` / `flutter test`. |
| `engineering-minimal-change-engineer` | `Read, Edit, Glob, Grep, Bash` | `sonnet` | `Write` omitted on purpose — it creates or wholesale-replaces files, the opposite of a minimum-viable diff. `Edit`-only makes the constraint structural instead of a promise in the prompt. |
| `engineering-mobile-release-engineer` | `Read, Glob, Grep, Bash` | `sonnet` | Can inspect and run the toolchain, cannot edit. Its blast radius would be `build.gradle.kts`, `project.pbxproj`, and signing config — expensive to get wrong, and it has no Flutter knowledge. |
| `design-ui-designer` | `Read, Glob, Grep` | `opus` | Advisory. Recommends hierarchy/spacing/design-system changes; a human applies them to `lib/`. |
| `product-behavioral-nudge-engine` | `Read, Glob, Grep` | `sonnet` | Advisory. Reasons about motivation and streak cadence, never needs to touch code. |

Net: one agent can create files, one can modify them, three are read-only.
`Bash` went only to the three with a real reason to run a toolchain.

## Caveat: none of these know Flutter

All five are framed for native iOS/Android and generic mobile tooling — there
are zero mentions of Flutter or Dart across the set. They will not know that a
`--flavor` argument is mandatory on every run and build here, and
`mobile-release-engineer` reaches for `fastlane` rather than
`flutter build appbundle --flavor prod`. Treat their output as advice to
translate, not commands to run. See the root `CLAUDE.md` for the real workflow.

## Updating

`scripts/install.sh` from the upstream repo **overwrites these files in place**
and will silently drop every `tools:` and `model:` line above. After any
re-install or update, reapply the table.
