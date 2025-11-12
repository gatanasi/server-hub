FROM caddy:2.10.2-builder@sha256:6e3ed727ce8695fc58e0a8de8e5d11888f6463c430ea5b40e0b5f679ab734868 AS builder

RUN xcaddy build \
    --with github.com/caddy-dns/cloudflare

FROM caddy:2.10.2@sha256:786b7527345b82faf39e664ea26c71cc57bcb3a89bb2eada94bf0b2dc5304f0a

RUN apk add --no-cache \
    curl \
    nss-tools

COPY --from=builder /usr/bin/caddy /usr/bin/caddy