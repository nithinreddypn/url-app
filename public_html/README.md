# URL Defender Hostinger API

This directory is an upload-ready PHP 8 REST API for the existing Hostinger
MySQL database. It does not contain migrations and never creates or alters a
table.

## Deploy

1. Upload the contents of this directory into Hostinger's `public_html`.
2. Copy `.env.example` to `.env` on Hostinger and enter the database values.
3. Set `APP_PUBLIC_URL` to the HTTPS site URL, without a trailing slash.
4. Set `APP_ALLOWED_ORIGINS` to a comma-separated list of web frontend origins.
   Native Android clients do not send or require a browser CORS origin.
5. Keep `.env`, `config`, and `middleware` inaccessible from the web. The
   supplied Apache/LiteSpeed `.htaccess` files enforce this.
6. Ensure `uploads` is writable by PHP (normally directory permission `755`).

Never commit or share the production `.env` file.

## Endpoints

All request bodies are JSON and all responses use this envelope:

```json
{
  "success": true,
  "message": "Request completed.",
  "data": {}
}
```

Endpoints are available with their PHP filename and, when rewrite rules are
enabled, without `.php`.

| Method | Endpoint | Authentication |
|---|---|---|
| POST | `/api/register.php` | Public |
| POST | `/api/login.php` | Public |
| POST | `/api/logout.php` | Bearer token |
| GET | `/api/profile.php` | Bearer token |
| PATCH or POST | `/api/update_profile.php` | Bearer token |
| POST | `/api/scan.php` | Bearer token |
| GET | `/api/history.php?limit=50&verdict=safe` | Bearer token |
| GET | `/api/blocked_urls.php` | Bearer token |

Use the login response's token as:

```http
Authorization: Bearer YOUR_TOKEN
Accept: application/json
Content-Type: application/json
```

Profile updates accept `full_name`. A profile image can be sent in JSON as
`avatar_base64`; JPEG, PNG, and WebP are accepted up to the configured size.

The currently supplied database schema has no `blocked_urls` table. Therefore
that endpoint returns HTTP `501` with a clear JSON message. It deliberately does
not create the missing table, in accordance with the no-schema-change rule.

## Quick checks

```bash
curl -i -X POST https://your-domain.example/api/register.php \
  -H "Content-Type: application/json" \
  -d '{"email":"person@example.com","full_name":"Person","password":"SecurePass123"}'

curl -i -X POST https://your-domain.example/api/login.php \
  -H "Content-Type: application/json" \
  -d '{"email":"person@example.com","password":"SecurePass123"}'
```

