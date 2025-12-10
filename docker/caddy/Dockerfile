FROM caddy:2-builder AS builder

RUN xcaddy build \
    --with github.com/caddy-dns/cloudflare

FROM caddy:2@sha256:dedfbbeb703b2ce9ff4a98fc06aa9c7c7d9a42f0b7d778738c1dd3ef11dcc767

RUN apk add --no-cache \
    curl \
    nss-tools

COPY --from=builder /usr/bin/caddy /usr/bin/caddy