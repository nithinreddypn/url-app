# Google Sign-In Audit Report

Date: 2026-07-16

## Scope

This audit covered only Google authentication configuration and flow:

- Flutter web and native Google Sign-In initialization
- The Google-rendered web button and authentication event handling
- Flutter-to-PHP ID-token exchange
- PHP ID-token verification and user/session creation
- Local origin, CORS, and popup response headers
- User-visible Google authentication errors

The general authentication design and unrelated backend behavior were not
changed.

## Root Cause

Google Identity Services validates the browser's exact origin. The Web OAuth
client authorizes:

```text
http://localhost:8080
```

Origins such as `http://127.0.0.1:8080` and `http://0.0.0.0:8080` are different
origins to Google, even though they reach the same local application. Loading a
GSI iframe from one of those aliases produced:

```text
The given origin is not allowed for the given client ID.
```

The earlier Flutter button lifecycle could also create more than one
iframe-backed GSI platform view during route/loading rebuilds. This explained
logs where one button instance successfully returned a credential while
another instance reported an origin 403.

The current implementation addresses both causes:

- Local IP aliases redirect to the authorized `localhost` origin before Flutter
  loads.
- Login and signup replace one another instead of keeping two Google buttons
  mounted in the route stack.
- The web Google button creates one stable iframe-backed widget per route.
- The local server sends
  `Cross-Origin-Opener-Policy: same-origin-allow-popups`.

## OAuth Client ID Audit

Downloaded OAuth files:

| Client type | Client ID | Used by web build |
| --- | --- | --- |
| Web | `729107585198-o142726sqh9aiigupv2objgfhg16kik9.apps.googleusercontent.com` | Yes |
| Installed/native | `729107585198-551l8kuipke85vqmr6umtpifabbj0145.apps.googleusercontent.com` | No |

The release `main.dart.js` contains exactly one
`apps.googleusercontent.com` client ID: the Web client ID above. It does not
contain the installed/native client ID.

The Web client ID currently matches in:

- `GOOGLE_WEB_CLIENT_ID`'s Flutter compile-time default
- `web/index.html`'s `google-signin-client_id` meta tag
- `backend/.env` as `GOOGLE_OAUTH_WEB_CLIENT_ID`
- The downloaded Web OAuth client JSON

No OAuth client secret is stored in the Flutter project or compiled web
application. The secret in Google's downloaded Web JSON is not used by this
GIS ID-token flow.

## Environment and Runtime Configuration

This is a Flutter application, not a Vite application.
`VITE_GOOGLE_CLIENT_ID` is therefore not used or expected.

Flutter equivalents:

| Setting | Current value/source |
| --- | --- |
| Google Web client | Compile-time `GOOGLE_WEB_CLIENT_ID` |
| API base URL | Compile-time `API_BASE_URL` |
| Default local API | `http://127.0.0.1:8123/api/v1` |

PHP equivalents:

| Setting | Current value/source |
| --- | --- |
| Google token audience | `GOOGLE_OAUTH_WEB_CLIENT_ID` in `backend/.env` |
| Backend public URL | `APP_URL=http://127.0.0.1:8123` |
| Allowed browser origins | `http://localhost:8080,http://127.0.0.1:8080` |

Verified runtime:

- Application origin: `http://localhost:8080`
- PHP API: `http://127.0.0.1:8123/api/v1`
- Flutter response status: HTTP 200
- PHP health response: HTTP 200
- Google popup header:
  `Cross-Origin-Opener-Policy: same-origin-allow-popups`
- Google endpoint CORS preflight: HTTP 204 with
  `Access-Control-Allow-Origin: http://localhost:8080`

## Google Cloud Console Configuration

Downloaded Web OAuth configuration:

### Authorized JavaScript origins

```text
http://localhost:8080
```

### Authorized redirect URIs

```text
http://localhost:8080
```

### Changes required now

No Google Cloud Console additions are required for the current local
application. The tested application origin already matches the downloaded Web
OAuth configuration exactly.

The application normalizes `127.0.0.1`, `0.0.0.0`, and IPv6 localhost aliases
to `localhost`, so those aliases do not need separate Google entries.

The current web flow uses the Google Identity Services credential button and
receives an ID token in the page; it does not use an OAuth redirect callback.
The configured local redirect URI is therefore not consumed by the current
button flow, but retaining it is harmless.

Before production deployment, add the exact deployed HTTPS origin, for example:

```text
https://your-real-domain.example
```

The real production hostname was not supplied, so no production URL was
invented or added to this report.

## Frontend Authentication Flow

```text
Official Google GIS button
        |
        v
GoogleSignIn.authenticationEvents
        |
        v
Google ID token
        |
        v
AuthService.signInWithGoogle()
        |
        v
POST /api/v1/auth/google
        |
        v
Opaque URL Defender session token + user
        |
        v
Riverpod userProvider update
        |
        v
/main
```

Verified implementation details:

- Web uses `initialize(clientId: webClientId)`.
- Web does not pass `serverClientId`.
- Native uses the Web client as `serverClientId` to request an ID token for
  backend verification.
- Web uses Google's official rendered button.
- The rendered web button remains stable during loading-state rebuilds.
- Only the current route consumes Google authentication events.
- The ID token is posted in JSON as `id_token`.
- The returned application token is stored through the existing API client.

## Backend Authentication Flow

The backend does not use a Google redirect callback endpoint. It uses:

```text
POST /api/v1/auth/google
```

The PHP endpoint:

1. Reads the server-side `GOOGLE_OAUTH_WEB_CLIENT_ID`.
2. Verifies the ID token's RS256 signature using Google's JWKS.
3. Validates issuer, audience, authorized party when required, expiration,
   subject, email format, and verified-email status.
4. Creates a verified user when the email is new.
5. Reuses the existing active user when the email already exists.
6. Creates the same opaque 30-day application session used by normal login.
7. Returns the application token and sanitized user profile.

An invalid-token request was verified to return a clean JSON 401 response. PHP
logic was not changed because no backend authentication defect was found.

## Error-Handling Fix

One remaining frontend defect was found during this audit: Google failures were
using the email/password error mapper. A failed Google token exchange could
therefore show `Invalid email or password`, and retry could submit the email
form or reuse the same Google token.

All Google SDK and token-exchange errors now pass through
`LoginErrorHandler.fromGoogleException()` and display only:

```text
Google Sign-In Unavailable

Unable to complete Google Sign-In. Please try again later or use email and
password.
```

The login action is `Use Email`. Signup does not resubmit the failed token.
Technical Google errors, client IDs, origins, API URLs, raw responses, and stack
traces are not copied into the UI. Detailed diagnostics remain debug-only.

## Files Modified

Changes made for the Google implementation and configuration:

- `lib/services/google_sign_in_service.dart`
- `lib/services/google_sign_in_service_web.dart`
- `lib/services/google_sign_in_service_native.dart`
- `lib/services/login_error_handler.dart`
- `lib/views/widgets/google_continue_button_web.dart`
- `lib/views/auth/auth_widgets.dart`
- `lib/views/auth/login_screen.dart`
- `lib/views/auth/signup_screen.dart`
- `web/index.html`
- `README.md`
- `test/unit/login_error_handler_test.dart`

Backend Google authentication files were audited but not modified for this
configuration/error-handling task:

- `backend/public/index.php`
- `backend/src/AuthController.php`
- `backend/src/GoogleIdTokenVerifier.php`
- `backend/src/Support.php`

## Verification Steps and Results

| Verification | Result |
| --- | --- |
| Flutter analyzer | Passed, no issues |
| Targeted LoginErrorHandler tests | 7 passed |
| Complete Flutter tests | 48 passed, 1 intentional skip |
| PHP syntax checks | Passed |
| Flutter release web build | Passed |
| Compiled Web client-ID inspection | Exactly one ID; correct Web client |
| Installed/native client in web bundle | Not present |
| API health | HTTP 200 |
| Google endpoint CORS preflight | HTTP 204, correct origin |
| Invalid Google token response | Clean JSON 401 |
| Clean release login page | Rendered; no GSI 403 |
| Clean release signup page | Rendered; no GSI 403 |
| `127.0.0.1` alias test | Redirected/rendered; no GSI 403 |
| Raw credential logging in release | Not present |
| COOP popup warning | Not present |
| Flutter/Dart assertion | Not present |

An actual account-selection interaction requires a user-controlled Google
session and cannot be automated without handling the user's Google account.
The configuration, button initialization, callback reception path, backend
exchange endpoint, token verifier, and clean-browser origin behavior were all
verified independently.
