#!/bin/sh
#
# certbot.sh - Entry point of the certbot sidecar for openspeedtest.
#
# Obtains the certificate once, renews it every 12 hours, copies it to where
# openspeedtest reads it, and restarts openspeedtest through the docker-api
# proxy. That proxy allows exactly one Docker API call: restarting openspeedtest.
#
# Usage (inside the certbot container):
#   certbot.sh               obtain if missing, install, then renew forever
#   certbot.sh deploy-hook   install the renewed certificate (run by certbot)
#
# Environment: CERTBOT_DOMAIN, CERTBOT_EMAIL, CLOUDFLARE_API_TOKEN, DOCKER_API.

set -eu

: "${CERTBOT_DOMAIN:?CERTBOT_DOMAIN is required}"
: "${CERTBOT_EMAIL:?CERTBOT_EMAIL is required}"
: "${CLOUDFLARE_API_TOKEN:?CLOUDFLARE_API_TOKEN is required}"
: "${DOCKER_API:?DOCKER_API is required}"

LIVE_DIR="/etc/letsencrypt/live/${CERTBOT_DOMAIN}"
OUT_DIR="/output_ssl"
CREDENTIALS="/secrets/cloudflare.ini"
SELF="/bin/sh /certbot.sh"
# openspeedtest runs nginx as uid 101; the key is readable by that uid only.
NGINX_UID=101

log() {
    echo "[certbot.sh] $*"
}

restart_openspeedtest() {
    if wget -q -O /dev/null --post-data='' "${DOCKER_API}/containers/openspeedtest/restart"; then
        log "Restarted openspeedtest"
    else
        log "ERROR: could not restart openspeedtest through ${DOCKER_API}" >&2
    fi
}

# Copy the live certificate to openspeedtest. Restart it only when the files changed.
install_cert() {
    changed=0
    cmp -s "${LIVE_DIR}/fullchain.pem" "${OUT_DIR}/nginx.crt" || changed=1
    cmp -s "${LIVE_DIR}/privkey.pem" "${OUT_DIR}/nginx.key" || changed=1

    cp "${LIVE_DIR}/fullchain.pem" "${OUT_DIR}/nginx.crt"
    cp "${LIVE_DIR}/privkey.pem" "${OUT_DIR}/nginx.key"
    chmod 644 "${OUT_DIR}/nginx.crt"
    chown "${NGINX_UID}" "${OUT_DIR}/nginx.key"
    chmod 600 "${OUT_DIR}/nginx.key"

    if [ "${changed}" -eq 1 ]; then
        log "Certificate files changed"
        restart_openspeedtest
    fi
}

if [ "${1:-}" = "deploy-hook" ]; then
    install_cert
    exit 0
fi

# Write the token to a root-only file. Reading it from the environment keeps it
# out of the container's command line and the host's process list.
mkdir -p "$(dirname "${CREDENTIALS}")"
umask 077
printf 'dns_cloudflare_api_token = %s\n' "${CLOUDFLARE_API_TOKEN}" > "${CREDENTIALS}"
umask 022

if [ ! -f "${LIVE_DIR}/fullchain.pem" ]; then
    log "No certificate for ${CERTBOT_DOMAIN}; requesting one"
    if ! certbot certonly \
        --non-interactive \
        --agree-tos \
        --dns-cloudflare \
        --email "${CERTBOT_EMAIL}" \
        --dns-cloudflare-credentials "${CREDENTIALS}" \
        --dns-cloudflare-propagation-seconds 60 \
        -d "${CERTBOT_DOMAIN}"; then
        # Wait before exiting so a restart loop can't hit Let's Encrypt rate limits.
        log "ERROR: initial certificate request failed; exiting in 1h" >&2
        sleep 1h
        exit 1
    fi
fi

# Also fixes ownership and mode of files written by older versions of this script.
install_cert

while :; do
    log "Checking for renewal"
    # A failed renewal is retried on the next pass instead of restarting the container.
    certbot renew --quiet --deploy-hook "${SELF} deploy-hook" \
        || log "ERROR: certbot renew failed; retrying in 12h" >&2
    sleep 12h
done
