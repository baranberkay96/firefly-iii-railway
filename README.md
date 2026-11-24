# Deploy and Host Firefly III with Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/firefly-iii-67-personal-finance-postgres?referralCode=20H68q)

Firefly III is a free, open-source personal finance manager: accounts, budgets, categories, bills, piggy banks, rules and reports, built on double-entry bookkeeping. This template runs it on Railway with Postgres, Redis, a daily cron job and an owner account that is created for you before the app goes online.

## About Hosting Firefly III

Firefly III is a Laravel (PHP) application. A production setup needs a database, a persistent storage folder (attachments, OAuth keys for the API), a cache and session store, and a daily call to its cron endpoint that creates recurring transactions, sends bill reminders and refreshes exchange rates. A fresh install lets the first visitor register and become the administrator. This community template pins the official 6.7.9 image, stores data in Postgres, sessions and cache in Redis, keeps the whole `storage` folder on a volume (so API tokens survive redeploys), runs the cron job daily, and creates the owner from your email and a generated password before nginx starts. Firefly III's single-user mode then keeps registration closed.

## Common Use Cases

- Tracking income, spending and account balances across banks, cards and cash
- Monthly budgets, bills and savings goals (piggy banks) with reports
- Automating categorisation with rules for imported transactions
- Multi-currency households and travellers
- A personal finance API for scripts, apps and the Firefly III Data Importer

## Dependencies for Firefly III Hosting

- Firefly III web service (nginx + PHP-FPM, official image) with a volume for `storage`
- Postgres (accounts, transactions, settings)
- Redis (sessions and cache)
- Cron service (daily call to `/api/v1/cron/{token}` on the private network)

### Deployment Dependencies

- [Firefly III documentation](https://docs.firefly-iii.org/)
- [Docker installation guide](https://docs.firefly-iii.org/how-to/firefly-iii/installation/docker/)
- [Cron jobs](https://docs.firefly-iii.org/how-to/firefly-iii/advanced/cron/)
- [Firefly III on GitHub](https://github.com/firefly-iii/firefly-iii)

### Implementation Details

| Service | What runs inside | Volume | Port |
|---|---|---|---|
| Firefly III | Firefly III 6.7.9 (nginx + PHP-FPM) | `/var/www/html/storage` | 8080, public domain |
| Cron | Alpine, calls the Firefly III cron endpoint daily at 03:00 UTC, then exits | none | none |
| Postgres | PostgreSQL 18 | `/var/lib/postgresql/data` | private |
| Redis | Redis 8.2 | `/data` | private |

**First login**

1. Enter your email in `FIREFLY_OWNER_EMAIL` when you deploy.
2. Open `https://{your-domain}` and log in with that email and the generated `FIREFLY_OWNER_PASSWORD` (Variables tab of the Firefly III service).
3. Follow Firefly III's first-run steps: default currency, your first asset account.

**Owner password.** `FIREFLY_OWNER_PASSWORD` is checked at every start: if it differs from the stored password of the user with `FIREFLY_OWNER_EMAIL`, the stored one is replaced. Change the variable and redeploy rather than changing the password in the app (an in-app change is reset at the next redeploy). A value shorter than 16 characters is ignored with a warning in the deploy log: an existing password stays, and a brand-new install gets a random owner password until you set a valid one. More users can be invited from the administration pages.

**Keys.** `APP_KEY` encrypts stored data and must stay the same for the life of the install. `STATIC_CRON_TOKEN` (32 characters) authorises the Cron service; you can run the jobs by hand from Railway's cron view ("Run now").

**Email.** Mail is written to the log by default (`MAIL_MAILER=log`). Railway allows outbound SMTP only on the Pro plan; on other plans use an HTTP API mailer Firefly III supports (`mailgun` with `MAILGUN_DOMAIN`/`MAILGUN_SECRET`, `mailersend` with `MAILERSEND_API_KEY`, `mandrill`, `sparkpost`).

**Importing data.** Firefly III imports through its separate Data Importer (CSV, camt.053, GoCardless, SimpleFIN, Spectre). It is not included to keep this template small and its upload page private; add it as another service from the `fireflyiii/data-importer` image with `FIREFLY_III_URL=http://${{Firefly III.RAILWAY_PRIVATE_DOMAIN}}:8080` and put it behind authentication if you give it a public domain.

**Scaling and upgrades.** Keep one Firefly III replica (the storage volume belongs to one service). The stack idles at roughly 0.4 GB RAM in total and fits Hobby; the web service alone fits Trial. To upgrade, eject the repo and change the `fireflyiii/core` tag and digest in `services/firefly/Dockerfile`, then redeploy; database migrations run on start. Back up Postgres before major upgrades.

### Why Deploy Firefly III on Railway?

Railway gives Firefly III managed Postgres and Redis, HTTPS, persistent storage and scheduled jobs in one project, so the complete self-hosted setup runs without a server to maintain. This template adds pinned versions, a database-backed healthcheck and an owner account created before anyone can reach the registration page.
