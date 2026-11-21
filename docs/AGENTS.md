# IXLand hackathon agent guide

IXLand supports monitoring after hospital discharge. The patient links a WHOOP or Samsung Galaxy Watch through the Flutter app. The app sends wearable observations to the backend in batches and displays the recovery status the backend returns. A future doctor dashboard will surface patients with reported complications.

The current implementation is in `mobile/`. It covers placeholder sign-in and heart-rate collection from WHOOP 4.0 and the IXLand Watch companion through a shared batch buffer. A separate developer owns the backend. The doctor dashboard is a secondary workstream for later.

| Path | Purpose |
| --- | --- |
| `docs/` | All Markdown files and project decisions. The root `AGENTS.md` (Codex) and `CLAUDE.md` (Claude Code) are both symlinks to this guide. |
| `mobile/` | Flutter patient app, wearable adapters, sync, and recovery UI. |
| `mobile/android/wear/` | Android Wear OS companion for the Galaxy Watch, built as a separate APK. |
| `docs/mobile-implementation.md` | What the Flutter app implements, implementation decisions, and how to run and verify it. |
| `docs/architecture.md` | Patient journey, mobile module boundaries, and the external backend and dashboard. |
| `docs/contracts.md` | Metric batch POST payload, configurable upload cadence, recovery status interface, and backend handoff. |
| `docs/hackathon-plan.md` | Flutter workstreams, build order, demo, and release gates. |

## Working across modules

1. Before editing, share the paths you expect to touch, dependencies, and the check that will show the work is complete. Coordinate changes to shared models and interfaces with their consumers.
2. Put provider implementations under `mobile/lib/wearables/` and register each adapter by its provider catalog ID. Adapters emit the common events in `wearable_adapter.dart`. Keep batching, queueing, and retries outside provider code. Keep backend payloads behind the gateway.
3. Build and test the patient flow with a synthetic wearable adapter and fake backend gateway. Confirm the real integration contract with the backend owner before committing to endpoint names, Firebase services, or storage layout.
4. At handoff, record changed paths, dependencies, setup and test commands, checks run, and any assumptions the next owner needs. Report fixture, staging, and real-device checks distinctly.

## Parallel agents and git

Two coding agents work on this repo at the same time, Codex and Claude Code, each in its own git worktree and on its own branch. Never edit files in the other agent's folder.

| Agent | Folder | Branch |
| --- | --- | --- |
| Codex | `ixland/` (main checkout) | `main`, or `codex/<feature>` for larger features |
| Claude Code | `../ixland-claude/` (git worktree) | `claude/<feature>` |

Claude creates its worktree from the repo root with `git worktree add ../ixland-claude -b claude/<feature>` and runs `flutter pub get` in `../ixland-claude/mobile/` before building.

1. Commit small, self-contained changes often on your own branch. Never commit to the other agent's branch, and don't force-push, rebase, or reset a branch you don't own.
2. Before starting a task and before handoff, run `git status` and `git log --oneline -5` so you don't build on stale or uncommitted state. Claude merges the latest `main` into its branch before handoff and resolves any conflicts there, not on `main`.
3. The user decides when to merge a feature branch into `main`. Don't merge into `main` yourself unless the user asks.
4. Some files are shared and likely to conflict: `mobile/pubspec.yaml`, `mobile/pubspec.lock`, `mobile/lib/wearables/wearable_adapter.dart`, shared models, `docs/contracts.md`, `docs/architecture.md`, and this guide. Keep edits to these files minimal and mention them in the commit message and the handoff. Don't reformat or reorder them.
5. In `docs/mobile-implementation.md`, add a new section for your feature rather than rewriting existing sections. Separate sections keep merges clean.
6. Generated files stay out of git, including `build/`, `.dart_tool/`, and `.flutter-plugins-dependencies`. Run `flutter pub get` after pulling dependency changes.
7. Both worktrees build the same application ID, so installing one on a device or emulator replaces the other. Say which branch you installed when you report real-device checks.

## Data and documentation

During implementation, keep patient data and credentials out of source, fixtures, logs, and screenshots. With each implementation change, update `docs/mobile-implementation.md` with what changed, decisions made, and how to verify the result. Keep Markdown under `docs/`. Use the acceptance checks in `docs/hackathon-plan.md` for the Flutter demo.
