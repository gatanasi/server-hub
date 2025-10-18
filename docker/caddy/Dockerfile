FROM caddy:2.10.2-builder@sha256:e8ec35d0787c123c0776d5e22570f2eeba76a730390104113554c271c40d2aeb AS builder

RUN xcaddy build \
    --with github.com/caddy-dns/cloudflare

FROM caddy:2.10.2@sha256:61a257991a7cca3d843218fb4a4eaf8b3241443fed67f43b5a2b56848237eba0

RUN apk add curl

COPY --from=builder /usr/bin/caddy /usr/bin/caddy