# Android Connectivity and Authentication Audit

## Scope

This audit traced the existing Flutter authentication and profile requests from
the UI through `AuthService`, `ApiClient`, the Android application manifest, and
the local PHP API. Backend endpoint behavior and authentication business rules
were not redesigned.

## Root Cause

The Android failures had multiple configuration causes:

1. `ApiClient` defaulted to `http://127.0.0.1:8123/api/v1` on every platform.
   On Android, `127.0.0.1` is the emulator or phone itself, not the development
   computer. Login, registration, password reset, profile, avatar, and every
   authenticated request therefore failed before reaching PHP.
2. The Android debug manifest did not permit cleartext HTTP. Android can block
   a local `http://` API even when the host address is correct.
3. The PHP development server listened only on `127.0.0.1:8123`. A physical
   phone cannot reach a loopback-only listener.
4. `backend/config/database.php` treated a LAN Host header as production even
   when `APP_ENV=development`. Once PHP was exposed to the LAN, requests made
   through the computer's LAN IP selected production placeholders and returned
   HTTP 500.
5. Google Cloud has the upload/release signing SHA-1, but `flutter run` signs
   the application with the debug keystore. The missing debug Android OAuth
   client causes native Google Sign-In to fail before token exchange.
6. Connection failures were always described as an internet problem, even when
   the actual cause was an unreachable local service.

The email Sign In button itself is wired correctly. It called `AuthService`,
but the request could not reach the configured endpoint.

## Existing Google Authentication Findings

- Flutter web uses the Web OAuth client ID.
- Native Flutter uses the same Web client ID as `serverClientId` so Google
  returns an ID token for the PHP API.
- The PHP API verifies the token against the same Web OAuth client ID.
- The Android package name is `com.urldefenders`.
- No Android redirect URI is used; the app exchanges the returned ID token at
  `POST /api/v1/auth/google`.
- A `google-services.json` file is not required by this implementation because
  the server client ID is supplied explicitly.

No Google authentication code or backend token-verification logic required a
change.

## Changes Made

### Flutter

- Added centralized platform-aware API resolution:
  - local web/desktop uses the local host;
  - Android emulator uses `10.0.2.2`;
  - physical devices use an explicit LAN URL supplied by the launch helper;
  - Android release builds require an explicit production HTTPS URL.
- Routed `ApiClient` and managed avatar URL resolution through the centralized
  configuration.
- Reworded connection errors so the UI no longer incorrectly claims the
  internet connection is down.

### Android

- Kept the existing `INTERNET` permission.
- Added a debug-only network security configuration that allows local HTTP.
- Confirmed the release manifest does not inherit cleartext permission or the
  debug network-security configuration.

### Local PHP configuration

- Made `APP_ENV` authoritative when choosing local versus production database
  configuration. `APP_ENV=development` now remains local when requests arrive
  through a LAN IP; `APP_ENV=production` remains production.
- Restarted the current project API on `0.0.0.0:8123` so a phone on the same
  private network can reach it.
- No controller, endpoint, authentication rule, database schema, or response
  contract was changed.

### Developer workflow

- Added `tool/start_backend_for_android.ps1` to expose the local PHP API.
- Added `tool/run_android.ps1` to identify whether the connected target is an
  emulator or physical device. Physical devices use ADB reverse so the phone
  can reach the PC API without relying on LAN/firewall routing.
- Documented local Android and production build commands in `README.md`.

## Files Modified

- `lib/config/api_environment.dart`
- `lib/services/api_client.dart`
- `lib/services/error_handler.dart`
- `lib/services/login_error_handler.dart`
- `android/app/src/debug/AndroidManifest.xml`
- `android/app/src/debug/res/xml/network_security_config.xml`
- `backend/config/database.php`
- `tool/run_android.ps1`
- `tool/start_backend_for_android.ps1`
- `test/unit/api_environment_test.dart`
- `test/unit/error_handler_test.dart`
- `test/unit/login_error_handler_test.dart`
- `README.md`

## Google Cloud Console Change Required

Create an additional OAuth client of type **Android**:

- Package name: `com.urldefenders`
- Debug SHA-1:
  `44:2C:27:DB:63:D5:75:E0:8C:40:C4:21:AA:26:59:A5:91:28:74:84`

The existing upload/release SHA-1 is:

`2D:DD:48:49:47:F6:0C:60:88:69:CB:B5:39:0A:4C:C9:3F:11:93:A1`

For Google Play builds, also create/use an Android OAuth client containing the
Play App Signing SHA-1 from Play Console.

Do not add JavaScript origins or redirect URIs to an Android OAuth client. Keep
`http://localhost:8080` on the Web OAuth client for local browser testing.

## Verification Results

- `flutter analyze`: passed with no issues.
- `flutter test`: all 57 tests passed.
- Debug APK: built successfully.
- Release APK with an explicit HTTPS `API_BASE_URL`: generated successfully.
- Debug merged manifest:
  - `INTERNET` permission present;
  - cleartext local HTTP enabled;
  - debug network security configuration present.
- Release merged manifest:
  - `INTERNET` permission present;
  - cleartext override absent;
  - debug network security configuration absent.
- PHP syntax check: passed.
- PowerShell helper syntax checks: passed.
- API listener: `0.0.0.0:8123`.
- Loopback health endpoint: HTTP 200.
- LAN health endpoint: HTTP 200.
- LAN endpoint probes:
  - email login route reached the API/database and returned expected HTTP 401
    for deliberately invalid credentials;
  - registration validation returned expected HTTP 422;
  - forgot-password returned expected HTTP 202;
  - Google token validation returned expected HTTP 422 for an empty token;
  - protected profile route returned expected HTTP 401 without a bearer token.

## Remaining Issues and External Verification

- The first APK installed during verification was a release compilation check
  containing the documented placeholder `https://api.example.com/api/v1`.
  That artifact was removed and must not be used for device testing. The
  correctly configured debug APK is generated through `tool/run_android.ps1`.
- No Android device is currently connected and no Android emulator is
  configured on this PC. Interactive Android testing of email login,
  registration, password reset, profile, and avatar upload could not be
  completed in this session.
- Native Google Sign-In will continue to fail in a debug `flutter run` build
  until the debug SHA-1 is registered in Google Cloud.
- A physical phone used with the helper must remain connected through an
  authorized USB or Wireless ADB session. Reconnect/re-run the helper after the
  device or computer restarts.
- Production Android builds require the real HTTPS API URL:

  `flutter build appbundle --dart-define=API_BASE_URL=https://your-api-domain.example/api/v1`

- The Hostinger production endpoint and Google Play App Signing SHA-1 were not
  available locally, so production network and Play-distributed Google Sign-In
  require final verification after those values are supplied.
