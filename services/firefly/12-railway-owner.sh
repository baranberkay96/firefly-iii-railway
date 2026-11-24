#!/bin/sh
# /etc/entrypoint.d/12-railway-owner.sh — runs after the image's
# 11-execute-things.sh (database migrations) and before /init starts nginx,
# so the owner account exists before the public port serves anything.
# Sourced by docker-php-serversideup-entrypoint; a non-zero exit stops the
# container (only when no user exists at all: fail closed).
echo "railway: creating or checking the Firefly III owner account"
php /railway/firefly-owner.php
