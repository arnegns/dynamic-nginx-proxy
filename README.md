# dynamic-nginx-proxy

[![Docker Image CI](https://github.com/arnegns/dynamic-nginx-proxy/actions/workflows/docker-build.yml/badge.svg)](https://github.com/arnegns/dynamic-nginx-proxy/actions/workflows/docker-build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A fully dynamic reverse proxy configurable via environment variables, built on NGINX.
Ideal for microservices setups, Docker stacks, and Kubernetes clusters.

Current project version: **1.1.2** (see [`VERSION`](VERSION)).
The base image is pinned to NGINX **1.31.10** on Debian **13 (trixie)** with a digest;
Dependabot checks for base image updates weekly.

## 🚀 Features

- **Unlimited routes** using `ROUTE_1_*`, `ROUTE_2_*`, …
- **Flexible per-route options** (headers, rewrites, timeouts, etc.)
- **Global proxy settings** via ENV variables
- **Debian-based image** compatible with older container seccomp profiles
- **Zero-downtime reloads** using NGINX template engine
- **Production-ready** - tested and deterministic

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
ROUTE_1_PROXY_SSL_SERVER_NAME=on
ROUTE_1_PROXY_SSL_NAME=prometheus.internal
ROUTE_1_HOST=prometheus.internal

# Route 2: API backend
ROUTE_2_PATH=/api
ROUTE_2_DEST=http://backend:8080/
ROUTE_2_TIMEOUT=60s

# Route 3: External redirect
ROUTE_3_PATH=/dashboard
ROUTE_3_REDIRECT=https://example.com/dashboard
ROUTE_3_REDIRECT_CODE=302
```

#### Route options

| Variable | Description | Default |
|----------|-------------|---------|
| `ROUTE_N_PATH` | URL path to proxy | - |
| `ROUTE_N_DEST` | Destination address (`http://` or `https://`) | - |
| `ROUTE_N_REDIRECT` | Client redirect target URL (uses `return`) | - |
| `ROUTE_N_REDIRECT_CODE` | Redirect status code (for example `301`, `302`, `307`, `308`) | `302` |
| `ROUTE_N_HEADERS` | Additional request headers | - |
| `ROUTE_N_STRIP_PREFIX` | Remove the path prefix before proxying | false |
| `ROUTE_N_REWRITE` | NGINX rewrite rule | - |
| `ROUTE_N_TIMEOUT` | Proxy read timeout | 30s |
| `ROUTE_N_PROXY_SSL_VERIFY` | Enable/disable TLS cert validation to HTTPS upstream (`on`/`off`) | NGINX default |
| `ROUTE_N_PROXY_SSL_SERVER_NAME` | Send SNI to HTTPS upstream (`on`/`off`) | NGINX default |
| `ROUTE_N_PROXY_SSL_NAME` | Explicit TLS server name used for certificate validation/SNI | - |
| `ROUTE_N_HOST` | Override `Host` header sent to upstream | - |

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

### Redirect instead of proxy

```bash
docker run -p 8080:8080 \
  -e ROUTE_1_PATH="/dashboard" \
  -e ROUTE_1_REDIRECT="https://example.com/dashboard" \
  -e ROUTE_1_REDIRECT_CODE="302" \
  ghcr.io/arnegns/dynamic-nginx-proxy:latest
```

### Local start with HTTPS upstream without certificate error

This example enables SNI and sets the upstream host explicitly, which is
usually required for public HTTPS endpoints.

```bash
docker build -t dynamic-nginx-proxy:dev .

docker run --rm -p 8080:8080 \
  -e ROUTE_1_PATH="/google" \
  -e ROUTE_1_DEST="https://google.de/" \
  -e ROUTE_1_STRIP_PREFIX="true" \
  -e ROUTE_1_PROXY_SSL_SERVER_NAME="on" \
  -e ROUTE_1_PROXY_SSL_NAME="google.de" \
  -e ROUTE_1_HOST="google.de" \
  dynamic-nginx-proxy:dev
```

Then open `http://localhost:8080/google`.

If your network does TLS inspection (corporate proxy), you may still see
certificate errors. For local testing only, you can disable verification:

```bash
-e ROUTE_1_PROXY_SSL_VERIFY="off"
```

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to your branch (`git push origin feature/AmazingFeature`)
5. Open a pull request

### Releasing

The GitHub Actions workflow builds pull requests, pushes to `main`, and any tag
matching `v*`. Images are published only for release tags. To create a new
release, update `VERSION` and the version above in a pull request. After merging,
tag the merged commit with the matching version and push the tag:

```sh
version="$(cat VERSION)"
git tag "v$version"
git push origin "v$version"
```

Once the tag is on GitHub the `docker-build.yml` workflow will execute, produce
images tagged `1.1.2`, `1.1` (major.minor), the commit SHA and `latest`.
The workflow rejects release tags that do not match
`VERSION`, and records the project version in the image's OCI version label.

You can verify the build in the Actions tab and pull the newly created image:

```bash
docker pull ghcr.io/arnegns/dynamic-nginx-proxy:1.1.2
```

### Development

The Debian base avoids a [musl 1.2.6 compatibility issue](https://github.com/nginx/docker-nginx/issues/1059)
where runtimes that deny `pwritev2` prevent NGINX from writing its PID file
(`pwrite() "/run/nginx.pid" failed (1: Operation not permitted)`).

Run the container smoke tests with Docker and Python 3:

```bash
docker build -t dynamic-nginx-proxy:test .
TEST_IMAGE=dynamic-nginx-proxy:test python3 tests/smoke.py
TEST_IMAGE=dynamic-nginx-proxy:test TEST_DENY_PWRITEV2=1 python3 tests/smoke.py
```

The second run uses a temporary test profile to deny only `pwritev2`, reproducing
the affected runtime's syscall failure. CI runs both checks before publishing.

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
- Debian – Compatible and maintained Docker base image

## 📞 Support

Have a question or found a bug? Please open an [issue](https://github.com/arnegns/dynamic-nginx-proxy/issues).
