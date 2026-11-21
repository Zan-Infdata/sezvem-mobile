# Mobile interfaces and backend handoff

The wearable upload fields below are the requested mobile-to-backend payload. The endpoint path, field semantics, and response codes are proposed for alignment with the backend developer. The mobile team can test the flow against a fake gateway.

## Wearable metric upload

Send one JSON object per batch over an authenticated HTTPS POST. Use `POST /v1/metric-batches` as the proposed route and `Content-Type: application/json`. All ten fields are required. Send both sleep fields as JSON `null` for regular batches. [JSON format](https://www.rfc-editor.org/rfc/rfc8259.html)

| Field | Type | Proposed meaning |
| --- | --- | --- |
| `patient_id` | `int` | Backend-assigned patient identifier. The service verifies that the authenticated caller may submit for this patient and active recovery episode. |
| `batch_timestamp` | `timestamp` | Start of the measurement window, encoded as a UTC RFC 3339 string ending in `Z`. The backend records receipt time separately. [Timestamp format](https://www.rfc-editor.org/rfc/rfc3339.html) |
| `b_number` | `int` | Increasing batch number scoped to the patient. Preserve it across retries and app restarts. Confirm how to resume the sequence after reinstall or a phone change. |
| `hr` | `int[]` | Heart-rate samples in beats per minute, ordered by measurement time within the window. |
| `sleep_start` | `timestamp\|null` | Start of a completed sleep session as a UTC RFC 3339 string ending in `Z`, or `null`. |
| `sleep_end` | `timestamp\|null` | End of the same session, in the same format and later than `sleep_start`, or `null`. |
| `temperature` | `float[]` | Temperature samples as finite JSON numbers in degrees Celsius, ordered by measurement time within the window. Confirm which measurement types to accept, such as skin temperature. |
| `steps` | `int` | Latest current step count reported by the wearable when the batch is prepared. Send the count as reported, with no deltas or accumulation. Repeated counts and device resets are valid. Zero represents a measured count of zero. |
| `spo2` | `int\|null` | Oxygen saturation as a whole percentage when supported. Send JSON `null` in every batch for now. |
| `batch_interval_in_seconds` | `int` | Positive duration of the measurement window in seconds. |

```json
{
  "patient_id": 123,
  "batch_timestamp": "2026-03-01T10:00:00Z",
  "b_number": 42,
  "hr": [71, 73, 72],
  "sleep_start": null,
  "sleep_end": null,
  "temperature": [33.4, 33.5],
  "steps": 4218,
  "spo2": null,
  "batch_interval_in_seconds": 300
}
```

Each window includes its start and excludes its end. Arrays are independent, may have different lengths, and carry no per-sample timestamps. Propose using an empty array for a metric with no samples. If a provider supplies no `steps` value, the current schema has no missing-value representation for that field. Agree on whether to hold or skip incomplete windows or revise the schema before using those providers in staging. Use only measured or agreed derived values.

## Completed sleep and backend HRV

Attach `sleep_start` and `sleep_end` together to the next eligible batch when a completed sleep session becomes available. Send each session in one logical batch. Both timestamps describe the sleep session and can be earlier than the batch window. If either timestamp is missing, send `null` for both until the session is complete.

```json
{
  "patient_id": 123,
  "batch_timestamp": "2026-03-01T10:05:00Z",
  "b_number": 43,
  "hr": [72, 74, 73],
  "sleep_start": "2026-02-28T22:46:00Z",
  "sleep_end": "2026-03-01T06:53:00Z",
  "temperature": [33.5],
  "steps": 4218,
  "spo2": null,
  "batch_interval_in_seconds": 300
}
```

Persist the association between a session and its batch so a provider resync or app restart does not schedule it again. On a retry, resend the same sealed batch with its original `b_number` and sleep values. The backend handles the HRV trigger idempotently.

When both timestamps are present, the backend uses the sleep window to calculate HRV from beat-to-beat intervals for that period. The `hr` array contains BPM samples. This payload still needs an agreed transport for the underlying intervals and their timestamps. If the sleep window arrives first, the backend can wait for the interval data before calculating HRV.

## Configurable upload cadence

- Configure a positive integer `batch_upload_interval_minutes` as the target time between upload runs. Confirm the default and configuration source with the backend developer. Start with measurement windows of the same length. A five-minute configuration uses 300-second windows, so the example covers 10:00 UTC up to 10:05 UTC.
- At each upload run, send completed windows. When a batch is known to have been rejected or never delivered, keep it in the buffer and append new completed windows from the same connection. Keep its first window start, append the heart-rate samples in order, and set `batch_interval_in_seconds` to the span through the end of the last included window. Two consecutive five-minute windows cover 600 seconds. Apply interval changes to new windows and leave unconfirmed payloads intact.
- Android may delay background uploads. If the app uses periodic WorkManager jobs, their minimum repeat interval is 15 minutes and run times depend on system scheduling. Agree on an acceptable delay and confirm whether the selected cadence must hold while the app is closed. [Android periodic work scheduling](https://developer.android.com/develop/background-work/background-tasks/persistent/getting-started/define-work#schedule_periodic_work)

## Acceptance and retries

- A live BLE adapter emits timestamped observations. A paged provider can also return an opaque cursor, which the sync coordinator persists with the observations. Scope the future durable queue to the active account, episode, and connection and seal each batch before sending it. Remove a queue item only after the backend durably accepts it. Pause transfer when the account changes, the episode closes, or access is revoked.
- Propose deduplicating by `(patient_id, b_number)` with a patient-scoped sequence. When acceptance is unknown, such as after a lost response, retry with the same JSON and batch number before sending newer data. A confirmed non-acceptance allows extending that batch with newer windows under the same number. Confirm sequence ownership before using multiple phones or changing phones. Use the measurement timestamp to process delayed batches in event time.
- Proposed responses are `202` for durably accepted, `200` for an already accepted identical batch, and `409` when the same identity arrives with different content. Retry timeouts, `429`, and transient server errors with backoff. Pause on expired login until the same account reauthenticates. Surface permanent rejections as sync errors. A receipt confirms storage. Recovery assessments arrive through the separate interface below.
- Record the latest measurement and latest successful upload separately. A successful wearable read with zero observations can update connectivity status.

## Recovery status and notices

The recovery gateway exposes the active episode and a snapshot for that episode, with optional updates if the backend supports them. The patient app can start with fetch on launch, resume, after upload, and on refresh. Confirm the cadence or subscription behavior with the backend owner.

| Proposed backend status | Flutter behavior |
| --- | --- |
| `on_track` | Show the approved favorable status when the assessment is current and the backend reports sufficient data. |
| `attention_needed` | Show the returned notice and approved next step, if provided. |
| `insufficient_data` | Explain that there is insufficient data for an assessment. Keep wearable connection and sync information visible. |
| `pending` or `unavailable` | Show the data or service state and when an earlier assessment was obtained, if available. Handle unknown status values as unavailable. |

The snapshot should include the episode ID, assessment time, data-through time, and an explicit freshness indicator or expiry. Notices need stable IDs, status, time, and approved patient-facing text or copy keys. Keep data freshness and assessment status distinct. A previously open notice can stay visible as a prior notice when a refresh fails, with the last known timestamp. Offline caches, late responses, and account switching must respect episode boundaries. Device-side logic handles presentation and freshness and never turns wearable measurements into a recovery assessment.

## Backend handoff to resolve before staging

| Area | Confirm with the backend developer |
| --- | --- |
| Identity and enrollment | Sign-in method, how a discharged patient receives access, episode ID and collection period, and responses for no active or completed episode. |
| Metric ingest | Route, auth, connection and episode association, default upload cadence, payload and array limits, unit conversions and scalar aggregation, incomplete windows, sequence ownership, and response codes. Confirm source provenance if batches can include data from more than one wearable. |
| Sleep and HRV | Confirm how to transmit time-aligned beat-to-beat intervals, handle late or incomplete coverage, and calculate HRV for the completed sleep window. |
| Samsung connection | Foreground heart rate currently comes from the Wear OS companion. Confirm consent and revocation behavior and how to handle the other required POST fields. |
| WHOOP connection | Live heart rate comes from Bluetooth. Agree on how to handle the other required POST fields. If adding cloud summaries, confirm OAuth redirect, server-side credentials, sandbox accounts, and who ingests the summaries. |
| Assessments | Actual status values, freshness, notice fields, approved patient copy and actions, update method, and possible acknowledgment behavior. |
| Environments | Staging project and credentials, synthetic test accounts and payloads, authentication and common error examples, and a way to test each status without real patient data. |
| Data handling | Who can access data, what happens to queued data when a connection or episode closes, retention and deletion responsibilities, and which request IDs are safe to log. |

The clinical owner confirms monitored metrics, patient wording, response expectations, and how flags reach a responsible clinician. The future doctor dashboard needs separate authorization restricted to assigned patients. The patient app receives patient-facing status for its own episode.
