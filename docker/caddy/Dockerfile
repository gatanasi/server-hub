FROM caddy:2.10.0-builder@sha256:6e7a8ab47f8663a71e07458bf7f58e258fda81697a5af99e9eb836d9341a953a AS builder

RUN xcaddy build \
    --with github.com/caddy-dns/cloudflare

FROM caddy:2.10.0@sha256:e23538fceb12f3f8cc97a174844aa99bdea7715023d6e088028850fd0601e2e2

RUN apk add curl

COPY --from=builder /usr/bin/caddy /usr/bin/caddy