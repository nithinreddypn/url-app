# Flutter Application Audit Report

Date: 2026-07-16

## Scope

Audited all Flutter/Dart source files, API client and repository calls, profile and avatar flows, Riverpod state propagation, model parsing, image rendering, and the existing Flutter tests. The current PHP route/controller responses were inspected read-only to verify the frontend contract. No backend behavior or backend file was changed during this audit.

## Issues found and resolved

| Area | Issue | Resolution |
| --- | --- | --- |
| Profile updates | The UI trusted the `PATCH /me` mutation response and did not fetch the canonical profile afterward. | `UserNotifier.updateProfile` now publishes the successful mutation immediately and then refreshes from `GET /me`. |
| Avatar uploads | The UI trusted only the upload response and did not reconcile it with the current profile. | `UserNotifier.uploadAvatar` now updates immediately and refreshes from `GET /me`. |
| Stale state | A slow initialization or refresh request could overwrite a newer login, update, avatar upload, or logout. | Operation/profile revisions now reject late responses and stale SharedPreferences writes. |
| Avatar cache | Flutter's decoded image cache was not invalidated after a changed avatar URL. | Old and new network image providers are evicted whenever the avatar changes. |
| Avatar widgets | A changed URL did not explicitly replace the existing image widget. | Home and Settings avatar images now use `ValueKey(avatarUrl)`. |
| Edit profile UX | The dialog closed before the API calls finished and allowed repeated actions. | The dialog remains open, disables actions, shows progress, closes only after success, and preserves errors in context. |
| API response envelopes | Successful JSON was accepted only when it decoded directly to a typed map; `{data: [...]}` envelopes were not normalized. | `ApiClient` now validates object responses and consistently unwraps map data or converts list data to `items`. |
| PHP/MySQL scalar types | Direct casts could crash when PDO returned numeric or boolean values as strings. | Added centralized parsing for strings, integers, doubles, booleans, dates, maps, and JSON/string lists; API-backed models and repositories use it. |
| Asset origins | Managed avatar URLs from an older/local backend origin could remain stale. | Auth profile parsing normalizes managed avatar paths to the active API origin. |
| Subscription source | Two hard-coded email addresses received a mock paid subscription. | Removed the mock entitlement; payment/profile API data is now the source of truth. |
| Subscription expiry | A captured payment was assigned a fresh 30-day expiry every time it was fetched. | Expiry is derived from the API payment creation time plus 30 days. |
| Scan usage fallback | An API failure reported 10 scans remaining, and loading cards assumed 50. | Failure/loading now falls back to zero instead of granting misleading client-side availability. |
| URL lookup lifecycle | A lookup HTTP client could remain open when a request failed. | Lookup clients are closed in `finally`, and only the active lookup can populate the cache. |
| Static quality | The project contained deprecated Flutter calls and unused legacy UI code. | Applied safe SDK migrations and removed unreachable/unused frontend code. |

## Required behavior verification

- Profile refreshes after every successful, non-superseded profile mutation.
- Avatar state updates immediately after upload and is reconciled with `GET /me`.
- Old/new network image cache entries are evicted when the avatar URL changes.
- Home and Settings replace the avatar image widget when its URL changes.
- API-backed model parsing tolerates the scalar encodings commonly returned by PHP/PDO.
- Riverpod publishes successful mutation state before persistence/reconciliation completes.
- Late requests and stale local-cache writes cannot overwrite newer profile state.
- Premium status and scan usage no longer use email-specific or permissive offline fallbacks.

## Verification performed

- `flutter analyze --no-pub`: passed with **0 issues**.
- `flutter test --no-pub`: passed with **47 tests**, plus one intentional debug-only skip.
- Added profile concurrency, canonical refresh, avatar refresh, PHP scalar parsing, lookup parsing, and subscription timestamp regression coverage.
- `flutter build web --release --no-wasm-dry-run`: completed successfully.

## Deployment note

The release build is available under `build/web`. A real hosted end-to-end profile/avatar test still depends on deploying this frontend build with the intended `API_BASE_URL` and using a valid hosted account/session; no production data was mutated as part of the audit.
