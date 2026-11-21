# IXLand hackathon agent guide

IXLand supports monitoring after hospital discharge. The patient links a WHOOP or Samsung Galaxy Watch through the Flutter app. The app sends wearable observations to the backend in batches and displays the recovery status the backend returns. A future doctor dashboard will surface patients with reported complications.

The current implementation is in `mobile/`. It covers placeholder sign-in and heart-rate collection from WHOOP 4.0 and the IXLand Watch companion through a shared batch buffer. A separate developer owns the backend. The doctor dashboard is a secondary workstream for later.

| Path | Purpose |
| --- | --- |
| `docs/` | All Markdown files and project decisions. The root `AGENTS.md` is a symlink to this guide. |
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

During implementation, keep patient data and credentials out of source, fixtures, logs, and screenshots. With each implementation change, update `docs/mobile-implementation.md` with what changed, decisions made, and how to verify the result. Keep Markdown under `docs/`. Use the acceptance checks in `docs/hackathon-plan.md` for the Flutter demo.
