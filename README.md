# netbird-sidecar

[![Docker Hub](https://img.shields.io/docker/v/lyhcode/netbird-sidecar?sort=semver&label=Docker%20Hub)](https://hub.docker.com/r/lyhcode/netbird-sidecar)
[![Build](https://github.com/lyhcode/netbird-sidecar/actions/workflows/build-push.yml/badge.svg)](https://github.com/lyhcode/netbird-sidecar/actions/workflows/build-push.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A ready-to-use [NetBird](https://netbird.io/) VPN sidecar container for Docker. Other containers can route their traffic through the NetBird network by sharing this container's network namespace.

## Quick Start

```bash
docker run -d \
  --name netbird-sidecar \
  --cap-add NET_ADMIN --cap-add SYS_ADMIN --cap-add SYS_RESOURCE \
  --device /dev/net/tun \
  -e NB_SETUP_KEY=your-setup-key \
  -e NB_MANAGEMENT_URL=https://api.netbird.io:443 \
  -v netbird-config:/var/lib/netbird \
  lyhcode/netbird-sidecar:latest
```

## Docker Compose (Sidecar Pattern)

Create a `.env` file from the template:

```bash
cp .env.example .env
# Edit .env with your NB_SETUP_KEY and NB_MANAGEMENT_URL
```

```yaml
services:
  netbird-sidecar:
    image: lyhcode/netbird-sidecar:latest
    container_name: netbird-sidecar
    cap_add:
      - NET_ADMIN
      - SYS_ADMIN
      - SYS_RESOURCE
    devices:
      - /dev/net/tun
    env_file: .env
    volumes:
      - netbird-config:/var/lib/netbird
    restart: unless-stopped

  # Your app shares the sidecar's network
  my-app:
    image: your-app:latest
    network_mode: "service:netbird-sidecar"
    depends_on:
      netbird-sidecar:
        condition: service_healthy

volumes:
  netbird-config:
```

The `network_mode: "service:netbird-sidecar"` directive makes `my-app` share the sidecar's network stack, so all outbound traffic from `my-app` routes through the NetBird VPN tunnel.

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `NB_SETUP_KEY` | Yes | — | NetBird setup key for peer enrollment |
| `NB_MANAGEMENT_URL` | No | `https://api.netbird.io:443` | NetBird management server URL |
| `NB_HOSTNAME` | No | Container hostname | Custom hostname for this peer |
| `NB_LOG_LEVEL` | No | `info` | Log level (`debug`, `info`, `warn`, `error`) |
| `NB_INTERFACE_NAME` | No | `wt0` | WireGuard interface name |
| `NB_WIREGUARD_PORT` | No | `51820` | WireGuard listen port |
| `NB_PRESHARED_KEY` | No | — | WireGuard preshared key |
| `NB_DISABLE_AUTO_CONNECT` | No | `false` | Disable automatic reconnection |

All `NB_*` environment variables are natively supported by the NetBird client binary.

## Required Capabilities

| Capability | Why |
|------------|-----|
| `NET_ADMIN` | Create and manage WireGuard tunnel interfaces |
| `SYS_ADMIN` | eBPF programs for NetBird's firewall and DNS features |
| `SYS_RESOURCE` | Increase memory limits for eBPF maps |

The `/dev/net/tun` device is required for tunnel creation.

## Health Check

The image includes a built-in health check that verifies the NetBird daemon is connected:

```
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3
  CMD netbird status --check live || exit 1
```

Use `depends_on` with `condition: service_healthy` in Docker Compose to ensure dependent containers wait for the VPN to be ready.

## Multi-Architecture

Supported platforms: `linux/amd64`, `linux/arm64`

## Building from Source

```bash
git clone https://github.com/lyhcode/netbird-sidecar.git
cd netbird-sidecar
docker build -t netbird-sidecar .

# Build with a specific NetBird version
docker build --build-arg NETBIRD_VERSION=0.67.4 -t netbird-sidecar .
```

## License

[MIT](LICENSE)
