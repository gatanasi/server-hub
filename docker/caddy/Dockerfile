FROM caddy:2.10.0-builder AS builder

RUN xcaddy build \
    --with github.com/caddy-dns/cloudflare

FROM caddy:2.10.0

RUN apk add curl

COPY --from=builder /usr/bin/caddy /usr/bin/caddy