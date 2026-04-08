---
name: netbird-sidecar
description: "NetBird VPN sidecar container for Docker: configuration, deployment, integration, and development. Use this skill when working with NetBird VPN containers, Docker sidecar patterns for VPN routing, WireGuard-based container networking, or the netbird-sidecar image. Also trigger when the user asks about routing container traffic through a VPN, setting up a VPN sidecar in Docker Compose, connecting containers to a NetBird network, or developing/modifying the netbird-sidecar project (Dockerfile, entrypoint, CI/CD). Even short requests like 'add VPN sidecar', 'setup netbird', or 'container VPN routing' should trigger this skill."
license: MIT
metadata:
  author: lyhcode
  version: '1.0.0'
tags:
  - docker
  - vpn
  - netbird
  - wireguard
  - sidecar
  - docker-compose
---

# NetBird Sidecar

A Docker container implementing the sidecar pattern for NetBird VPN. Other containers share its network namespace via `network_mode: "service:netbird-sidecar"`, routing all their traffic through a NetBird VPN tunnel without any VPN configuration of their own.

- **Image**: `lyhcode/netbird-sidecar:latest`
- **Base**: Alpine Linux 3.21
- **Architectures**: linux/amd64, linux/arm64
- **Source**: https://github.com/lyhcode/netbird-sidecar

## How the Sidecar Pattern Works

The core mechanism is Docker's `network_mode: "service:<sidecar>"`. When an app container uses this, it shares the sidecar's entire network stack. The app sees the sidecar's interfaces, IP addresses, and routes — so all traffic flows through the VPN tunnel automatically. The app container needs zero VPN configuration.

The sidecar requires elevated Linux capabilities because NetBird uses WireGuard and eBPF:

| Capability | Why |
|------------|-----|
| `NET_ADMIN` | Create and manage WireGuard tunnel interfaces |
| `SYS_ADMIN` | Load eBPF programs for firewall and DNS |
| `SYS_RESOURCE` | Increase memory limits for eBPF maps |

The `/dev/net/tun` device must also be mounted. Missing any of these causes the container to fail.

## Deployment

### 1. Create .env

Copy from the template and fill in your NetBird setup key (obtained from the NetBird management console — it's a one-time enrollment token that registers this container as a peer):

```bash
cp .env.example .env
```

Required:
```
NB_SETUP_KEY=your-actual-setup-key
NB_MANAGEMENT_URL=https://api.netbird.io:443
```

### 2. Docker Compose

```yaml
services:
  netbird-sidecar:
    image: lyhcode/netbird-sidecar:latest
    container_name: netbird-sidecar
    hostname: my-app-vpn  # NetBird uses this as the peer's FQDN — set explicitly
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

  my-app:
    image: your-app:latest
    network_mode: "service:netbird-sidecar"
    depends_on:
      netbird-sidecar:
        condition: service_healthy

volumes:
  netbird-config:
```

Important details:
- Set `hostname` on the sidecar container — NetBird uses it as the peer's FQDN in the network, so a meaningful name makes peers easier to identify and manage
- `network_mode: "service:netbird-sidecar"` — shares the VPN network stack
- `depends_on` with `condition: service_healthy` — waits for VPN to connect
- The `netbird-config` volume persists VPN state across container restarts

### 3. Quick Start (single container, no Compose)

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

### 4. Verify

```bash
docker compose up -d
docker compose ps                                    # Check health status
docker compose logs netbird-sidecar                  # View connection logs
docker exec netbird-sidecar netbird status           # Check VPN peer connectivity
```

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `NB_SETUP_KEY` | Yes | — | NetBird setup key for peer enrollment |
| `NB_MANAGEMENT_URL` | No | `https://api.netbird.io:443` | Management API endpoint — the gRPC service the client connects to for VPN operations |
| `NB_ADMIN_URL` | No | `https://app.netbird.io` | Admin panel URL — required for self-hosted NetBird; points to the dashboard where peers and networks are managed |
| `NB_HOSTNAME` | No | Container hostname | Peer hostname — NetBird uses this as the FQDN for the peer, so set it explicitly to something meaningful (e.g., `my-app-vpn`) rather than relying on the auto-generated container hostname |
| `NB_LOG_LEVEL` | No | `info` | Log level: `debug`, `info`, `warn`, `error` |
| `NB_INTERFACE_NAME` | No | `wt0` | WireGuard interface name |
| `NB_WIREGUARD_PORT` | No | `51820` | WireGuard listen port |
| `NB_PRESHARED_KEY` | No | — | WireGuard preshared key |
| `NB_DISABLE_AUTO_CONNECT` | No | `false` | Disable automatic reconnection |
| `NB_ENTRYPOINT_SERVICE_TIMEOUT` | No | `30` | Seconds to wait for daemon startup |

All `NB_*` variables are read natively by the NetBird client binary — no wrapper logic needed.

## Troubleshooting

### Container exits immediately or won't start
1. Check all three capabilities are present: `NET_ADMIN`, `SYS_ADMIN`, `SYS_RESOURCE`
2. Check `/dev/net/tun` is mounted (`devices: [/dev/net/tun]`)
3. Validate the setup key is not expired — keys are one-time use by default

### Health check keeps failing
1. Check logs: `docker compose logs netbird-sidecar`
2. The health check runs `netbird status --check live` — if the daemon started but can't reach the management server, this fails
3. Start period is 15s with 30s intervals — give it time on first boot
4. Verify management URL is reachable from the host network

### App can't reach VPN resources
1. Confirm `network_mode: "service:netbird-sidecar"` on the app service
2. Confirm `depends_on` with `condition: service_healthy`
3. Check peer connectivity: `docker exec netbird-sidecar netbird status`
4. DNS through VPN requires the NetBird DNS feature configured on the management server side

### Setup key problems
- Default setup keys are single-use — generate a new one for re-deployments
- For testing, create a reusable key in the NetBird management console
- Self-hosted management servers: ensure URL includes the port (e.g., `:443`)

## Development

### Project Structure

```
netbird-sidecar/
├── Dockerfile                        # Alpine + NetBird binary download
├── entrypoint.sh                     # Daemon lifecycle + signal handling
├── docker-compose.yml                # Example sidecar deployment
├── .env.example                      # Env var template
├── .github/workflows/
│   ├── build-push.yml                # Multi-arch build → Docker Hub
│   └── dockerhub-description.yml     # README → Docker Hub sync
├── README.md / CHANGELOG.md / LICENSE
```

### Entrypoint Lifecycle

`entrypoint.sh` runs this sequence:
1. `netbird service run &` — start daemon in background
2. Wait up to `NB_ENTRYPOINT_SERVICE_TIMEOUT` seconds for daemon readiness
3. `netbird up` — initiate VPN connection
4. Report assigned IP, then `wait` on the background process
5. On SIGTERM/SIGINT — `kill -TERM` the daemon, then exit cleanly

### Building from Source

```bash
docker build -t netbird-sidecar .

# Pin a specific NetBird version
docker build --build-arg NETBIRD_VERSION=0.68.0 -t netbird-sidecar .
```

### Updating NetBird Version

1. Edit `Dockerfile`: change `ARG NETBIRD_VERSION=X.Y.Z`
2. Test locally: `docker build -t netbird-sidecar .`
3. Update `CHANGELOG.md`
4. Commit, tag (`git tag vX.Y.Z`), push with tags
5. CI builds and pushes automatically

### CI/CD Pipeline

GitHub Actions workflow (`build-push.yml`):
- **Triggers**: push to `main`, version tags `v*.*.*`, pull requests
- **Process**: QEMU + buildx → multi-arch build (amd64 + arm64) → push to Docker Hub
- **Tags**: semantic versioning (major, major.minor, major.minor.patch, sha)
- **PR builds**: build only, no push
- **Required secrets**: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`

### Adding Environment Variables

NetBird reads `NB_*` env vars natively. When a new version adds new variables:
1. Add to `.env.example` (commented out if optional)
2. Document in the Environment Variables table in `README.md`
3. No changes to `entrypoint.sh` needed
