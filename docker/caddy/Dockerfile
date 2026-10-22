FROM caddy:2.11.7-builder@sha256:671d2a6e5465cc894c9ca57706c7ea7d101018059fe3154c65805a0eda550467 AS builder

RUN xcaddy build \
    --with github.com/caddy-dns/cloudflare

FROM caddy:2.11.7@sha256:3095ad245c353e3bdb27a38f22a095c1cfa9e295ab21c0214c3e72b0e2960525

RUN apk add --no-cache \
    curl \
    nss-tools

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
