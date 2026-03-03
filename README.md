# dynamic-nginx-proxy

[![Docker Image CI](https://github.com/arnegns/dynamic-nginx-proxy/actions/workflows/docker-build.yml/badge.svg)](https://github.com/arnegns/dynamic-nginx-proxy/actions/workflows/docker-build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Ein vollständig dynamischer, per Umgebungsvariablen konfigurierbarer Reverse Proxy auf Basis von NGINX. Perfekt für Microservices-Architekturen und Kubernetes-Umgebungen.

## 🚀 Features

- **Beliebig viele Routen** - `ROUTE_1_*`, `ROUTE_2_*`, … (keine Begrenzung)
- **Flexible Route-Optionen** - Custom Headers, Rewrites, Timeouts, etc.
- **Globale Proxy-Einstellungen** - Zentrale Konfiguration per ENV-Variablen
- **Minimalistisches Alpine-Image** - Kleine Docker-Images, schnelle Deployments
- **Zero-Downtime-Configuration** - Reload ohne Service-Unterbrechung
- **Production-Ready** - Getestet und in Produktion einsatzbereit

## 📦 Installation

### Mit Docker

```bash
docker pull ghcr.io/arnegns/dynamic-nginx-proxy:latest
```

### Mit Docker Compose

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

Protokoll-Routing ist jetzt aktiv:
- `http://localhost:8080/prometheus` → `http://prometheus:9090/`
- `http://localhost:8080/api` → `http://backend:8080/`

## 🔧 Konfiguration

### Route-Umgebungsvariablen

Jede Route wird mit dem Pattern `ROUTE_<N>_<OPTION>` konfiguriert:

```env
# Route 1: Prometheus Metrics
ROUTE_1_PATH=/prometheus
ROUTE_1_DEST=http://prometheus:9090/
ROUTE_1_HEADERS="X-Foo: bar, X-Bar: baz"
ROUTE_1_STRIP_PREFIX=true
ROUTE_1_REWRITE="^/prometheus/(.*) /$1"
ROUTE_1_TIMEOUT=30s

# Route 2: API Backend
ROUTE_2_PATH=/api
ROUTE_2_DEST=http://backend:8080/
ROUTE_2_TIMEOUT=60s
```

#### Route-Optionen

| Variable | Beschreibung | Standard |
|----------|-------------|----------|
| `ROUTE_N_PATH` | URL-Pfad zum Proxieren | - |
| `ROUTE_N_DEST` | Ziel-Adresse (http/https) | - |
| `ROUTE_N_HEADERS` | Zusätzliche HTTP-Header | - |
| `ROUTE_N_STRIP_PREFIX` | Pfad-Präfix entfernen | false |
| `ROUTE_N_REWRITE` | NGINX Rewrite-Regel | - |
| `ROUTE_N_TIMEOUT` | Proxy-Timeout | 30s |

### Globale Umgebungsvariablen

```env
GLOBAL_PORT=8080
GLOBAL_MAX_BODY_SIZE=50m
GLOBAL_READ_TIMEOUT=60s
GLOBAL_CONNECT_TIMEOUT=10s
GLOBAL_KEEPALIVE_TIMEOUT=65s
```

## 📚 Beispiele

### Einfaches Proxying

```bash
docker run -p 8080:8080 \
  -e ROUTE_1_PATH="/service" \
  -e ROUTE_1_DEST="http://myservice:3000/" \
  ghcr.io/arnegns/dynamic-nginx-proxy:latest
```

### Mit Path-Rewriting

```bash
docker run -p 8080:8080 \
  -e ROUTE_1_PATH="/old-api" \
  -e ROUTE_1_DEST="http://api:8080/" \
  -e ROUTE_1_REWRITE="^/old-api/(.*) /v2/$1" \
  ghcr.io/arnegns/dynamic-nginx-proxy:latest
```

### Mit Custom Headers

```bash
docker run -p 8080:8080 \
  -e ROUTE_1_PATH="/secure" \
  -e ROUTE_1_DEST="http://backend:8080/" \
  -e ROUTE_1_HEADERS="Authorization: Bearer token123, X-Client-ID: mobile" \
  ghcr.io/arnegns/dynamic-nginx-proxy:latest
```

## 🤝 Contributing

Beiträge sind willkommen! Bitte beachten Sie:

1. Fork das Repository
2. Erstellen Sie einen Feature-Branch (`git checkout -b feature/AmazingFeature`)
3. Committen Sie Ihre Änderungen (`git commit -m 'Add some AmazingFeature'`)
4. Pushen Sie zum Branch (`git push origin feature/AmazingFeature`)
5. Öffnen Sie einen Pull Request

### Development

```bash
# Docker Image lokals bauen
docker build -t dynamic-nginx-proxy:dev .

# Testen
docker run -p 8080:8080 \
  -e ROUTE_1_PATH="/test" \
  -e ROUTE_1_DEST="http://example.com/" \
  dynamic-nginx-proxy:dev
```

## 📄 Lizenz

Dieses Projekt ist unter der MIT-Lizenz lizenziert - siehe [LICENSE](LICENSE) für Details.

## 👤 Autor

Arne Giesbach - [@arnegns](https://github.com/arnegns)

## 🙏 Danksagungen

- [NGINX](https://nginx.org/) - The High Performance Web Server
- Alpine Linux - Minimal and Efficient Docker Base Image

## 📞 Support

Haben Sie eine Frage oder gefunden ein Bug? Bitte öffnen Sie ein [Issue](https://github.com/arnegns/dynamic-nginx-proxy/issues).
