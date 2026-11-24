# NOTICE: Firefly III template

This is a community template. It is not made, endorsed or supported by the Firefly III project or Railway.

## Components

| Component | Source | License | How it is used |
|---|---|---|---|
| Firefly III 6.7.9 (`fireflyiii/core:version-6.7.9@sha256:10bbe21fbdc68b8fa955d85827aeed197ab46d62c8c745e949d322b9f4b73ff5`) | https://github.com/firefly-iii/firefly-iii | AGPL-3.0-or-later (Copyright James Cole) | Official image, unmodified, used as the base image. Source code: https://github.com/firefly-iii/firefly-iii/tree/v6.7.9 |
| serversideup/php (base of the Firefly III image) | https://github.com/serversideup/docker-php | GPL-3.0 | Inside the official image |
| Alpine Linux 3.24.4 (`alpine:3.24.4@sha256:f59abe65…`) | https://hub.docker.com/_/alpine | Each package's own license | Cron service (busybox `wget`) |
| PostgreSQL 18 (`ghcr.io/railwayapp-templates/postgres-ssl`) | https://github.com/railwayapp-templates/postgres-ssl | PostgreSQL License | Database |
| Redis 8.2 | https://hub.docker.com/_/redis | Redis' license for 8.x (RSALv2/SSPLv1/AGPLv3) | Sessions and cache |

## Files written for this template

`services/firefly/Dockerfile`, `railway-start.sh`, `12-railway-owner.sh`, `firefly-owner.php` and the documentation were written for this template and are offered under the MIT License. `firefly-owner.php` calls Firefly III's own classes (`User`, the `NewUserRegistered` event, `UserGroup`, `GroupMembership`, `UserRole`) inside the running image; no Firefly III source files are copied.

## Upstream files checked (tag v6.7.9 unless noted)

- `firefly-iii/docker`: `docker-compose-importer.yml` (services, volume `/var/www/html/storage/upload`, daily cron call), `.env.example` in the main repo (variable names and defaults)
- `firefly-iii/base-image`: `Dockerfile.web`, `scripts/execute-things-web.sh` (entrypoint.d hook, migrations via the image's `entrypoint.sh`)
- `serversideup/docker-php`: `docker-php-serversideup-entrypoint` (entrypoint.d order and failure handling)
- `app/Http/Controllers/Auth/RegisterController.php` (single-user mode), `app/Listeners/Security/System/HandlesNewUserRegistration.php` (owner role, administration), `app/Console/Commands/System/CreatesFirstUser.php`, `app/Http/Controllers/System/HealthcheckController.php` (`/health` checks the database), `config/logging.php`

## Market templates

The Railway marketplace templates `-7wtOV` (Firefly III), `firefly-iii` and `fireflyiii` were reviewed for features only. No files or text were copied.
