# URL Defender PHP API

PHP 8.2+ / MySQL 8 backend for URL Defender. It contains authentication, sessions, verification and reset emails, an asynchronous VirusTotal scan worker, notifications, scan quotas, Razorpay payment verification/webhooks, role-gated admin APIs, and retention cleanup.

For Hostinger deployment, follow [HOSTINGER.md](HOSTINGER.md). You do not need PHP or MySQL installed on your Windows PC.

## Configure and run

1. Install PHP 8.2+ with the `pdo_mysql`, `curl`, and `openssl` extensions, plus MySQL 8.
2. Copy `.env.example` to `.env`. `.env` is ignored by Git: place provider secrets there only, never in Flutter or source control. Database credentials are isolated in `config/database.php`; localhost automatically uses the XAMPP configuration in that file.
3. Run the schema and operational migration once:

   ```powershell
   mysql -u root -p < database/schema.sql
   mysql -u root -p url_defender < database/002_runtime_tables.sql
   mysql -u root -p url_defender < database/003_scans_lookup_indexes.sql
   php cli/migrate_scans_lookup.php
   ```

4. Start the API:

   ```powershell
   php -S 127.0.0.1:8123 -t public public/index.php
   ```

5. Start the scan worker in another terminal. Use `--once` for a scheduler or omit it for a long-running worker.

   ```powershell
   php cli/scan_worker.php
   php cli/cleanup.php
   ```

Schedule `cleanup.php` daily. Run one or more workers under a process manager in production.

## Provider configuration

- `VIRUSTOTAL_API_KEY`: server-only key used by `cli/scan_worker.php`.
- `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`: server-only order creation and confirmation. The API returns only the publishable `RAZORPAY_KEY_ID` to the client checkout flow.
- `RAZORPAY_WEBHOOK_SECRET`: configure the same value in Razorpay's dashboard webhook settings; webhooks call `POST /api/v1/payments/webhook`.
- `MAIL_TRANSPORT=log` writes local development messages to ignored `storage/mail.log`. For Gmail SMTP, set `MAIL_TRANSPORT=smtp`, `SMTP_HOST=smtp.gmail.com`, `SMTP_PORT=465`, `SMTP_ENCRYPTION=ssl`, and use a Gmail App Password as `SMTP_PASSWORD`. The Gmail address must also be `MAIL_FROM` and `SMTP_USERNAME`.

Set `APP_ALLOWED_ORIGINS` to the exact comma-separated browser origins that may call the API. HTTPS is mandatory in production. `PASSWORD_RESET_URL` must be the Flutter web/deep-link reset page, not an API URL.

## API

All JSON endpoints are under `/api/v1`. Send `Authorization: Bearer <session_token>` after sign-in unless noted otherwise.

| Method | Path | Access | Purpose |
| --- | --- | --- | --- |
| GET | `/health` | Public | Health check. |
| POST | `/auth/register` | Public | Creates user, role, and a hashed email OTP. |
| POST | `/auth/verify-email` | Public | Verifies the email OTP. |
| POST | `/auth/resend-verification` | Public | Sends a replacement OTP with request limits. |
| POST | `/auth/login` | Public | Creates opaque 30-day bearer session. |
| POST | `/auth/logout` | User | Revokes current session. |
| POST | `/auth/forgot-password` | Public | Emails reset link without account enumeration. |
| POST | `/auth/reset-password` | Public | Sets password and revokes all sessions. |
| POST | `/auth/change-password` | User | Verifies `current_password`, changes to `new_password`, and revokes other sessions. |
| GET | `/me` | User | Gets current user. |
| PATCH | `/me` | User | Updates the display name and selected profile icon. |
| POST | `/me/avatar` | User | Uploads a JPEG, PNG, or WebP profile image (1 MB max). |
| POST | `/url/lookup` | User | Looks up a normalized URL in completed `scans` rows only; never calls VirusTotal. |
| GET/POST | `/scans` | User | Lists scans / returns cached analysis or queues a new URL scan. |
| GET | `/scans/{id}` | Owner | Scan result and engine results. |
| DELETE | `/scans/{id}` | Owner | Deletes one scan and related result data. |
| GET | `/usage` | User | Current monthly scan usage and remaining free quota. |
| GET/PATCH | `/notifications`, `/notifications/{id}/read` | User | Notification inbox. |
| GET | `/plans` | User | Team and enterprise price catalog. |
| POST | `/payments/orders` | User | Creates Razorpay checkout order for `plan`. |
| POST | `/payments/verify` | User | Validates checkout signature and provider payment status. |
| POST | `/payments/webhook` | Razorpay | HMAC-verified, idempotent payment webhook. |
| GET | `/payments` | User | Payment history. |
| GET | `/admin/users`, `/admin/audit-log` | Admin/moderator as noted | Administrative records. |
| PATCH | `/admin/users/{id}/status` | Admin | Enables/disables user and revokes sessions on disable. |

## Flutter contract

Configure the app's API base as `http://127.0.0.1:8123/api/v1` for a local Windows browser. An Android emulator must use `http://10.0.2.2:8123/api/v1`; a real phone must use the computer's LAN IP and a secured HTTPS deployment. Save the `token` returned by `/auth/login` in secure storage and attach it as a bearer token. Never put VirusTotal, Razorpay secret, mail, or database credentials in Flutter.

The payment checkout client sends Razorpay's `razorpay_order_id`, `razorpay_payment_id`, and `razorpay_signature` to `/payments/verify`. The server, not Flutter, checks the signature and fetches the payment from Razorpay before activating a plan.

## Instant URL intelligence

The shared lookup cache is intentionally implemented with the existing `scans` table. Completed rows are found by `normalized_url_hash`; no additional threat-intelligence table is required. `POST /url/lookup` is database-only and returns sanitized analysis fields plus personal-history metadata only when the authenticated user owns a matching scan.

Creating a scan first checks the same cache. A cache hit creates the user's personal history row and copies the stored analysis without contacting VirusTotal. For a cache miss, workers coordinate with a MySQL advisory lock and an oldest-job leader check, so concurrent requests for the same normalized URL reuse one provider analysis.
