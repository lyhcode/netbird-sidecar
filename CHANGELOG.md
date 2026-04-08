# Changelog

## 1.0.0 (2026-04-08)

- Initial release
- Alpine-based image with NetBird v0.67.4
- Built-in health check (`netbird status --check live`)
- Sidecar pattern support via `network_mode: service:netbird-sidecar`
- Multi-architecture: `linux/amd64`, `linux/arm64`
- GitHub Actions CI/CD with automated Docker Hub publishing
