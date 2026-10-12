FROM caddy:2.11.7-builder@sha256:5b98e8a4c3d077585c5980b205cfcc9602d820675d5e0cfdbf5eeff939dc0b4a AS builder

RUN xcaddy build \
    --with github.com/caddy-dns/cloudflare

FROM caddy:2.11.7@sha256:f2a1290d0463aad60660d4ec134943f183ee2a5f6c3eb7bf32dd984f2f020772

RUN apk add --no-cache \
    curl \
    nss-tools

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
