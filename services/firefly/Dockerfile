# syntax=docker/dockerfile:1
#
# Firefly III 6.7.9 for Railway.
#
# Base: the official image (serversideup/php 8.6 fpm-nginx, Debian), tag
# version-6.7.9 pinned by digest (pushed 2026-11-24). To upgrade, change the
# tag and digest together (Docker Hub, fireflyiii/core) and redeploy.
#
# Added on top:
# - railway-start.sh (runs as root): prepares the /var/www/html/storage
#   volume, checks the variables, then drops to www-data and starts the
#   image's own entrypoint.
# - 12-railway-owner.sh + firefly-owner.php: create the owner account from
#   variables after the migrations and before nginx starts.
FROM fireflyiii/core:version-6.7.9@sha256:10bbe21fbdc68b8fa955d85827aeed197ab46d62c8c745e949d322b9f4b73ff5

USER root
# Keep a copy of the image's storage skeleton: the volume mounted over
# /var/www/html/storage starts empty and is seeded from it at every start.
RUN cp -a /var/www/html/storage /opt/railway-storage-skeleton

COPY --chmod=0755 railway-start.sh /railway/railway-start.sh
COPY --chmod=0644 firefly-owner.php /railway/firefly-owner.php
COPY --chmod=0755 12-railway-owner.sh /etc/entrypoint.d/12-railway-owner.sh

ENV PORT=8080
EXPOSE 8080
ENTRYPOINT ["/railway/railway-start.sh"]
CMD ["/init"]
