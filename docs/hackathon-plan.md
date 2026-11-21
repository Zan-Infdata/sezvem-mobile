# IXLand Flutter delivery plan

## Scope

Deliver the Android-first Flutter flow for a discharged patient to sign in, link an existing WHOOP or Samsung Galaxy Watch, upload data in batches, and view recovery updates from the backend. Use synthetic inputs and fake backend responses for the first integrated demo. The external backend and future doctor dashboard remain dependencies and context for the mobile plan.

## Parallel workstreams

| Workstream | Deliverable | Start with |
| --- | --- | --- |
| Flutter app and patient UI | Sign-in and episode flow, wearable setup, recovery status, notices, and sync troubleshooting. | Design against fake session, connection, and recovery states. |
| Samsung adapter | Wear OS companion, heart-rate permission, nearby phone discovery, and shared batch mapping. | Verify live BPM and sample count from the Galaxy Watch4 on the paired Android phone. |
| WHOOP adapter | Discover and connect to a broadcasting strap over Bluetooth and collect normalized live heart-rate samples. | Verify discovery and repeated samples on a physical phone and strap. Agree on the backend handling of heart-rate-only batches. |
| Sync and gateway | Account-scoped queue, recovery gateway, durable acceptance, retry, and disconnect behavior. | Use synthetic pages and backend responses from the proposed contract. |
| Integration lead | Coordinate with the backend developer and clinical owner. Verify flows and record dependencies. | Resolve the backend handoff in `docs/contracts.md` and record staging and device setup. |

One person or agent can cover several workstreams. Share the adapter types and gateway models before work branches. Keep wearable adapters independently testable.

## Milestones

1. **Prove the phone path.** Agree on the initial episode and recovery states, then build the Flutter flow against a fixture adapter and fake gateway. Exercise normal, attention needed, and unavailable states.
2. **Verify wearable access in parallel.** Prove Galaxy Watch companion discovery, permissions, and foreground heart-rate streaming on hardware. Confirm WHOOP Bluetooth discovery, connection, and live heart rate with a physical strap. Keep fixture-based work moving while backend staging is prepared.
3. **Complete mobile sync.** Wire the adapters through the common queue. Verify restart, retry, account changes, and permission revocation. Use the same transport interface for fakes and staging.
4. **Integrate with staging.** Swap in the real gateway, verify sign-in and episode identity, and confirm each wearable route can produce an accepted batch. Confirm the patient UI receives the intended backend state, including a synthetic notice.
5. **Rehearse the demo.** Use a dedicated test account. Show which data comes from a real wearable import and which assessment is simulated. Defer background syncing, push notifications, iOS validation, and the doctor dashboard until the core mobile flow works.

## Demo and acceptance

- Sign in, select a wearable, grant the required access, and open the assigned recovery episode. Show the source connection, latest measurement, and last successful upload.
- Upload one batch and show durable acceptance through the gateway. Replay that batch after a simulated lost response and verify the queue and staging receipt handle the duplicate consistently.
- Change the upload interval and verify that new measurement windows use the new duration. Reconnect with multiple queued windows and check that each POST uses its original timestamp, duration, and batch number.
- Use a synthetic assessment to show both a favorable recovery status and a notice requiring attention. Verify no-data, stale, and service-unavailable states stay distinguishable from a favorable status.
- Go offline, queue a page, restart the app, and reconnect. Verify queued data resumes for the same account and episode, permission revocation stops new reads, and switching accounts does not expose or upload the earlier account's data.
- Verify the Samsung path on a real Android phone and Galaxy Watch. Verify the WHOOP path on a physical Android phone with Heart Rate Broadcast enabled on the strap. Record fixture, staging, and hardware checks separately.

Before using the app with discharged patients, the clinical owner and backend developer need to agree on monitored metrics, expected data freshness, clinical validation, alert routing and review responsibility, and patient-facing instructions. The mobile team needs to verify access, consent and disconnect behavior, and data retention and deletion end to end in staging.
