# dynamic-nginx-proxy

[![Docker Image CI](https://github.com/arnegns/dynamic-nginx-proxy/actions/workflows/docker-build.yml/badge.svg)](https://github.com/arnegns/dynamic-nginx-proxy/actions/workflows/docker-build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A fully dynamic reverse proxy configurable via environment variables, built on NGINX.
Ideal for microservices setups, Docker stacks, and Kubernetes clusters.

## 🚀 Features

- **Unlimited routes** using `ROUTE_1_*`, `ROUTE_2_*`, …
- **Flexible per-route options** (headers, rewrites, timeouts, etc.)
- **Global proxy settings** via ENV variables
- **Minimal Alpine-based image** for fast pulls and low attack surface
- **Zero-downtime reloads** using NGINX template engine
- **Production-ready** - small, tested, and deterministic

## 📦 Installation

### Docker

```bash
docker pull ghcr.io/arnegns/dynamic-nginx-proxy:latest
```

### Docker Compose

```yaml
services:
  nginx-proxy:
    image: ghcr.io/arnegns/dynamic-nginx-proxy:latest
    ports:
      - "8080:8080"
    environment:
      GLOBAL_PORT: 8080
      GLOBAL_MAX_BODY_SIZE: 50m
      ROUTE_1_PATH: /prometheus
      ROUTE_1_DEST: http://prometheus:9090/
      ROUTE_2_PATH: /api
      ROUTE_2_DEST: http://backend:8080/
```

## 🎯 Quick Start

```bash
docker run -p 8080:8080 \
  -e ROUTE_1_PATH="/prometheus" \
  -e ROUTE_1_DEST="http://prometheus:9090/" \
  -e ROUTE_2_PATH="/api" \
  -e ROUTE_2_DEST="http://backend:8080/" \
  ghcr.io/arnegns/dynamic-nginx-proxy:latest
```

The following routing is now active:
- `http://localhost:8080/prometheus` → `http://prometheus:9090/`
- `http://localhost:8080/api` → `http://backend:8080/`

## 🔧 Configuration

### Per-route environment variables

Each route is configured using variables matching the pattern `ROUTE_<N>_<OPTION>`.

```env
# Route 1: Prometheus metrics
ROUTE_1_PATH=/prometheus
ROUTE_1_DEST=http://prometheus:9090/
ROUTE_1_HEADERS="X-Foo: bar, X-Bar: baz"
ROUTE_1_STRIP_PREFIX=true
ROUTE_1_REWRITE="^/prometheus/(.*) /$1"
ROUTE_1_TIMEOUT=30s

# Route 2: API backend
ROUTE_2_PATH=/api
ROUTE_2_DEST=http://backend:8080/
ROUTE_2_TIMEOUT=60s
```

#### Route options

| Variable | Description | Default |
|----------|-------------|---------|
| `ROUTE_N_PATH` | URL path to proxy | - |
| `ROUTE_N_DEST` | Destination address (`http://` or `https://`) | - |
| `ROUTE_N_HEADERS` | Additional request headers | - |
| `ROUTE_N_STRIP_PREFIX` | Remove the path prefix before proxying | false |
| `ROUTE_N_REWRITE` | NGINX rewrite rule | - |
| `ROUTE_N_TIMEOUT` | Proxy read timeout | 30s |

### Global environment variables

These variables control the behaviour of the embedded NGINX instance. Values
not provided will fall back to the defaults listed below.

| Variable | Description | Default |
|----------|-------------|---------|
| `GLOBAL_PORT` | Port that NGINX listens on | `8080` |
| `GLOBAL_MAX_BODY_SIZE` | Value for `client_max_body_size` | `20m` |
| `GLOBAL_READ_TIMEOUT` | Value for `proxy_read_timeout` | `60s` |
| `GLOBAL_CONNECT_TIMEOUT` | Value for `proxy_connect_timeout` | `10s` |
| `GLOBAL_KEEPALIVE_TIMEOUT` | Value for `keepalive_timeout` | `65s` |
| `DEBUG` | Show generated config when `true` | `false` |

Example of overriding global settings:

```bash
docker run -e GLOBAL_PORT=9090 \
  -e DEBUG=true \
  ghcr.io/arnegns/dynamic-nginx-proxy:latest
```

## 📚 Examples

### Simple proxying

```bash
docker run -p 8080:8080 \
  -e ROUTE_1_PATH="/service" \
  -e ROUTE_1_DEST="http://myservice:3000/" \
  ghcr.io/arnegns/dynamic-nginx-proxy:latest
```

### Path rewriting

```bash
docker run -p 8080:8080 \
  -e ROUTE_1_PATH="/old-api" \
  -e ROUTE_1_DEST="http://api:8080/" \
  -e ROUTE_1_REWRITE="^/old-api/(.*) /v2/$1" \
  ghcr.io/arnegns/dynamic-nginx-proxy:latest
```

### Custom headers

```bash
docker run -p 8080:8080 \
  -e ROUTE_1_PATH="/secure" \
  -e ROUTE_1_DEST="http://backend:8080/" \
  -e ROUTE_1_HEADERS="Authorization: Bearer token123, X-Client-ID: mobile" \
  ghcr.io/arnegns/dynamic-nginx-proxy:latest
```

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to your branch (`git push origin feature/AmazingFeature`)
5. Open a pull request

### Releasing

The GitHub Actions workflow is configured to run on pushes to `main` and on
any tag matching `v*`.  To create a new release and build the Docker image
versioned accordingly, tag the repository and push the tag:

```sh
git tag v1.0.0          # adjust semver as needed
# optionally add a lightweight or annotated message: git tag -a v1.0.0 -m "First release"
git push origin v1.0.0
```

Once the tag is on GitHub the `docker-build.yml` workflow will execute, produce
images tagged `v1.0.0`, `1.0` (major.minor), the commit SHA and `latest` if
the tag points at `main`.

You can verify the build in the Actions tab and pull the newly created image:

```bash
docker pull ghcr.io/arnegns/dynamic-nginx-proxy:v1.0.0
```

### Development

```bash
# build the image locally

docker build -t dynamic-nginx-proxy:dev .

# run against a test route

docker run -p 8080:8080 \
  -e ROUTE_1_PATH="/test" \
  -e ROUTE_1_DEST="http://example.com/" \
  dynamic-nginx-proxy:dev
```

## 📄 License

This project is licensed under the MIT License – see [LICENSE](LICENSE) for details.

## 👤 Author

Arne Gnisa - [@arnegns](https://github.com/arnegns)

## 🙏 Acknowledgements

- [NGINX](https://nginx.org/) – The High Performance Web Server
- Alpine Linux – Minimal and efficient Docker base image

## 📞 Support

Have a question or found a bug? Please open an [issue](https://github.com/arnegns/dynamic-nginx-proxy/issues).
