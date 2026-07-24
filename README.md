# url-defender
Cybersecurity Mobile Application for URL Threat Detection
# URL Defender

## Debug-only test login

Use this only to preview authentication and UI flows while the Hostinger API is
unavailable. It is disabled by default and cannot run in release builds. Supply
the credentials at launch time so they are not stored in this repository.

```powershell
flutter run -d chrome `
  --dart-define=ENABLE_TEST_LOGIN=true `
  --dart-define=TEST_LOGIN_EMAIL=your-test-email `
  --dart-define=TEST_LOGIN_PASSWORD=your-test-password
```

This local session does not test SMTP, MySQL, payments, or URL scanning.

## Local web sign-in

Google Cloud authorizes `http://localhost:8080` as the browser origin. Start
Flutter with the popup-compatible response header and open the localhost URL:

```powershell
flutter run -d web-server `
  --web-hostname=0.0.0.0 `
  --web-port=8080 `
  --web-header=Cross-Origin-Opener-Policy=same-origin-allow-popups
```

Open `http://localhost:8080/#/auth_gate`. Local IP aliases are redirected to
`localhost` so Google Identity Services always receives the registered origin.

## Local Android development

The application resolves the backend differently on each platform:

- Local web/desktop: `http://127.0.0.1:8123/api/v1` (or the current local web
  hostname).
- Android emulator: `http://10.0.2.2:8123/api/v1`.
- Physical Android device: USB/Wireless ADB reverse, configured automatically
  by `tool/run_android.ps1`.
- Production: an HTTPS address supplied with `--dart-define=API_BASE_URL=...`.

For an Android emulator, keep the local PHP API running and use:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\run_android.ps1
```

For a physical Android device, enable USB debugging, connect it to the
computer, accept the debugging prompt, and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\run_android.ps1
```

The helper creates an ADB reverse mapping from the phone's port `8123` to the
computer's PHP server. `tool/start_backend_for_android.ps1` remains available
when LAN testing from another device is specifically required.

The debug Android manifest permits cleartext HTTP only for local development.
Release builds remain HTTPS-only and must be built with an explicit endpoint:

```powershell
flutter build appbundle `
  --dart-define=API_BASE_URL=https://your-api-domain.example/api/v1
```

### Google Sign-In on Android

The native application uses package name `com.urldefenders`. Google Cloud must
contain separate Android OAuth clients for each signing certificate:

- Debug SHA-1:
  `44:2C:27:DB:63:D5:75:E0:8C:40:C4:21:AA:26:59:A5:91:28:74:84`
- Upload/release SHA-1:
  `2D:DD:48:49:47:F6:0C:60:88:69:CB:B5:39:0A:4C:C9:3F:11:93:A1`
- Google Play distribution: add the Play App Signing SHA-1 shown by Play
  Console after Play App Signing is enabled.

The Web OAuth client remains the server client ID used to issue the ID token
that the PHP API verifies. Android OAuth clients do not use JavaScript origins
or redirect URIs.
