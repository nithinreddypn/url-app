# Deploying to Hostinger

Use a dedicated HTTPS subdomain such as `api.yourdomain.com`. Point its document root to the `backend/public` directory; this keeps `.env`, source code, SQL files, and CLI scripts outside the web-accessible folder.

## 1. Upload files

Upload the full `backend` folder outside `public_html` if your Hostinger plan permits it. In hPanel, configure the `api` subdomain document root as:

```text
/home/<hosting-user>/backend/public
```

The included `public/.htaccess` sends `/api/v1/...` requests to `index.php`.

If your plan cannot set a subdomain document root, contact Hostinger support to configure it. Do **not** upload `src`, `.env`, or `database` into a publicly browsable directory.

## 2. Database

In hPanel, create a MySQL database and database user. In phpMyAdmin, import in this order:

1. `database/schema.sql`
2. `database/002_runtime_tables.sql`

Replace the four `HOSTINGER_DB_*` placeholders in `backend/config/database.php`. That private file is the only database-credential location used by URL Defender. Do not modify the separate shared `public_html/config/database.php`. Then create `backend/.env` from `.env.example` and set:

```ini
APP_ENV=production
APP_DEBUG=false
APP_URL=https://api.yourdomain.com
PASSWORD_RESET_URL=https://yourdomain.com/#/reset-password
APP_ALLOWED_ORIGINS=https://yourdomain.com
```

Add your provider credentials only after the deployment health check succeeds. `.env` is ignored by Git and must never be placed in Flutter or committed.

For Gmail verification and password-reset emails, use:

```ini
MAIL_TRANSPORT=smtp
MAIL_FROM=your-gmail-address@gmail.com
MAIL_FROM_NAME=URL Defender
SMTP_HOST=smtp.gmail.com
SMTP_PORT=465
SMTP_ENCRYPTION=ssl
SMTP_USERNAME=your-gmail-address@gmail.com
SMTP_PASSWORD=your-16-character-google-app-password
```

Enable 2-Step Verification on the Gmail account first, then generate an App Password. Do not use your normal Google password.

Ensure `backend/public/uploads/avatars` is writable by PHP (normally folder permission `755`). Uploaded profile photos are limited to JPEG, PNG, and WebP files up to 1 MB.

## 3. PHP settings

Select PHP 8.2 or newer in hPanel. Enable the `curl`, `openssl`, and `pdo_mysql` extensions. Visit:

```text
https://api.yourdomain.com/api/v1/health
```

It should respond with `{"status":"ok"}`.

## 4. Scheduled jobs

Hostinger shared hosting does not run a permanent worker process. Create these cron jobs in hPanel:

```text
* * * * * /usr/bin/php /home/<hosting-user>/backend/cli/scan_worker.php --once
15 3 * * * /usr/bin/php /home/<hosting-user>/backend/cli/cleanup.php
```

Confirm the PHP binary path with Hostinger if `/usr/bin/php` differs on your plan.

## 5. Flutter production build

Build Flutter with the deployed API URL:

```powershell
flutter build web --dart-define=API_BASE_URL=https://api.yourdomain.com/api/v1
```

For Android/iOS, use the same `--dart-define`. The client sends only user input and the session token; VirusTotal, Razorpay secret, mail, and database credentials remain on Hostinger.
