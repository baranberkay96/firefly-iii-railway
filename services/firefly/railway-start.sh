#!/bin/bash
# Start Firefly III on Railway (runs as root, then drops to www-data).
#
# 1. Seed the storage volume from the image's skeleton (never overwriting
#    data) and give it to www-data. Railway mounts volumes as root and does
#    not create the folders the image declares with VOLUME.
# 2. Check the variables. A bad value never stops the deploy (STANDARD 8.29):
#    an APP_KEY that is not 32 characters is turned into a stable 32-character
#    key, a bad owner email falls back to admin@example.com, and an empty or
#    short owner password never opens the registration page (the owner gets
#    a random password instead).
# 3. exec the image's entrypoint as www-data: migrations (11-execute-things),
#    owner account (12-railway-owner), then nginx + PHP-FPM via /init.
set -euo pipefail

STORAGE=/var/www/html/storage
DEFAULT_EMAIL=admin@example.com
MIN_PASSWORD=16
MAX_PASSWORD=128

log() { printf '%s railway-start: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }

mkdir -p "$STORAGE"
cp -an /opt/railway-storage-skeleton/. "$STORAGE"/
mkdir -p "$STORAGE"/{app/public,build,database,debugbar,export,logs,upload} \
         "$STORAGE"/framework/{cache/data,sessions,testing,views}
find "$STORAGE" \( ! -user www-data -o ! -group www-data \) -exec chown www-data:www-data {} +

# Laravel needs exactly 32 bytes for AES-256-CBC. Keep a valid key as it is;
# derive a stable one from anything else so encrypted data stays readable.
key=${APP_KEY:-}
if [[ $key == base64:* ]]; then
  decoded_len=$(printf '%s' "${key#base64:}" | base64 -d 2>/dev/null | wc -c || echo 0)
  if [[ $decoded_len -ne 32 ]]; then
    log "WARNING: APP_KEY base64 value is not 32 bytes; using a key derived from it"
    APP_KEY=$(printf '%s' "$key" | sha256sum | cut -c1-32)
  fi
elif [[ ${#key} -ne 32 ]]; then
  log "WARNING: APP_KEY must be exactly 32 characters (has ${#key}); using a key derived from it." \
      "Set a 32-character APP_KEY before you store data, and never change it afterwards."
  APP_KEY=$(printf '%s' "${key:-firefly-iii-railway}" | sha256sum | cut -c1-32)
fi
export APP_KEY

token=${STATIC_CRON_TOKEN:-}
if [[ ${#token} -ne 32 ]]; then
  log "WARNING: STATIC_CRON_TOKEN must be exactly 32 characters (has ${#token}); the Cron service's daily calls will be refused."
fi

email=${FIREFLY_OWNER_EMAIL:-}
if ! [[ $email =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]]; then
  log "FIREFLY_OWNER_EMAIL='$email' is not an email address; using $DEFAULT_EMAIL"
  email=$DEFAULT_EMAIL
fi
export RAILWAY_OWNER_EMAIL=$email
export SITE_OWNER=${SITE_OWNER:-$email}

password=${FIREFLY_OWNER_PASSWORD:-}
if ((${#password} < MIN_PASSWORD || ${#password} > MAX_PASSWORD)); then
  log "WARNING: FIREFLY_OWNER_PASSWORD must be $MIN_PASSWORD-$MAX_PASSWORD characters (has ${#password})." \
      "An existing password is kept; a new owner gets a random password nobody knows." \
      "Set a valid FIREFLY_OWNER_PASSWORD on the service and redeploy to log in."
  export RAILWAY_OWNER_MODE=lock
else
  export RAILWAY_OWNER_MODE=set
fi
# Hand the password to firefly-owner.php through a private file (it deletes
# it), so it does not stay in the environment of nginx and PHP-FPM.
PASSWORD_FILE=/tmp/railway-owner-password
# Write first, then chown: /tmp is sticky and fs.protected_regular stops root
# from opening an existing file there that belongs to www-data.
rm -f "$PASSWORD_FILE"
(umask 077 && printf '%s' "$password" > "$PASSWORD_FILE")
chown www-data:www-data "$PASSWORD_FILE"
export RAILWAY_OWNER_PASSWORD_FILE=$PASSWORD_FILE
unset FIREFLY_OWNER_PASSWORD password

HOME=$(getent passwd www-data | cut -d: -f6)
export HOME
log "Starting Firefly III as www-data (storage on the volume at $STORAGE)"
exec setpriv --reuid=www-data --regid=www-data --init-groups docker-php-serversideup-entrypoint "$@"
