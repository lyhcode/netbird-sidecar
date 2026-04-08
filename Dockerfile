FROM alpine:3.21

ARG TARGETARCH
ARG NETBIRD_VERSION=0.67.4

LABEL org.opencontainers.image.title="netbird-sidecar"
LABEL org.opencontainers.image.description="NetBird VPN sidecar container for Docker"
LABEL org.opencontainers.image.source="https://github.com/lyhcode/netbird-sidecar"
LABEL org.opencontainers.image.vendor="lyhcode"
LABEL org.opencontainers.image.licenses="MIT"

RUN apk add --no-cache \
    bash \
    ca-certificates \
    iptables \
    ip6tables \
    iproute2 \
    curl

RUN ARCH="${TARGETARCH}" \
    && if [ "${ARCH}" = "arm64" ]; then ARCH="arm64"; fi \
    && curl -fsSL "https://github.com/netbirdio/netbird/releases/download/v${NETBIRD_VERSION}/netbird_${NETBIRD_VERSION}_linux_${ARCH}.tar.gz" \
       -o /tmp/netbird.tar.gz \
    && tar -xzf /tmp/netbird.tar.gz -C /usr/local/bin netbird \
    && chmod +x /usr/local/bin/netbird \
    && rm /tmp/netbird.tar.gz

ENV NB_LOG_FILE=console

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD netbird status --check live || exit 1

ENTRYPOINT ["/entrypoint.sh"]
