# Backend architecture

```text
Flutter / web checkout
        | HTTPS + opaque bearer token
        v
PHP API
  AuthController         users, roles, OTPs, reset links, sessions, login attempts
  ScanController         quota reservation + scans + scan_jobs enqueue
  PaymentController      Razorpay orders, verification, HMAC webhooks, payments
  AdminController        role-checked user operations and audit log
        |                         |
        v                         v
     MySQL 8               Razorpay / mail provider
        ^
        |
PHP scan worker --> VirusTotal --> scan_results / scan_engines / notifications
```

`scan_jobs` and `webhook_events` are operational tables in `002_runtime_tables.sql`. `scan_jobs` lets multiple workers safely claim one pending scan; `webhook_events` deduplicates Razorpay payloads before a payment state changes.

Security decisions:

- Passwords and one-time verification codes use Argon2id hashes. Sessions and reset links retain only SHA-256 hashes of random values.
- Provider credentials are read only from `.env`; only Razorpay's key ID may reach the checkout client.
- Scan URLs are submitted to VirusTotal rather than fetched by the PHP API, avoiding server-side requests to user-controlled hosts.
- Payment activation requires a valid checkout HMAC and a provider-side payment lookup. Webhooks independently verify their own HMAC and are idempotent.
- Admin access is checked against `user_roles` in the database. Client claims are never trusted.
- `cleanup.php` removes expired secrets and bounds retention. Production should run it daily and use HTTPS, a process supervisor, database backups, monitoring, and a restricted origin allowlist.
