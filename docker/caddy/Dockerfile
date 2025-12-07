FROM caddy:2@sha256:cef7fe17d4df3b0843eae25bed319d6140b1a7bb13ccef076f5f1783d5bca9b1 AS builder

RUN xcaddy build \
    --with github.com/caddy-dns/cloudflare

FROM caddy:2@sha256:cef7fe17d4df3b0843eae25bed319d6140b1a7bb13ccef076f5f1783d5bca9b1

RUN apk add --no-cache \
    curl \
    nss-tools

COPY --from=builder /usr/bin/caddy /usr/bin/caddy