# Zot OCI Registry

Local [Zot](https://zotregistry.dev/) registry with HTTPS API and UI on one port.

## Quick start

```bash
make gencerts genhtpasswd
mkdir -p data   # if data/ is not already a bind mount
make run
make addr       # → localhost:1244
```

UI / API: `https://localhost:1244`

```bash
docker login localhost:1244 -u lenik -p 2Bw1ijPadpTX
curl -u lenik:2Bw1ijPadpTX -k https://localhost:1244/v2/
```

## Users (htpasswd / bcrypt)

| User | Password | Role |
|------|----------|------|
| `lenik` | `2Bw1ijPadpTX` | admin — read/create/update/delete on all repos |
| `zot` | `2Bw1ijPadpTX` | normal — read/create/update |
| `guest` | `V6RiHvGv5a29` | guest — read only |

Anonymous access is disabled. Regenerate hashes: `make genhtpasswd-force`.

## Make targets

| Target | Purpose |
|--------|---------|
| `gencerts` / `gencerts-force` | Self-signed TLS (`certs/domain.*`) |
| `genhtpasswd` / `genhtpasswd-force` | bcrypt `htpasswd` for the users above |
| `run` | Create and start the container |
| `start` / `stop` / `rm` | Lifecycle |
| `shell` | `docker exec` into the container |
| `net-mode` | Print resolved network mode |
| `addr` | Print host URL |

## Ports & listen

| Role | Value | Where |
|------|-------|--------|
| Listen address | `[::]` | all IPv4 + IPv6 (`config.json` → `http.address`) |
| Container port | `8080` | `http.port` |
| Host publish | `1244` | `-p 1244:8080` (bridge) or rewritten config (host) |

## Network mode

`NETWORK_MODE=auto|host|bridge` (default `auto`).

- **bridge** — publishes `SERVER_PORT:CONTAINER_PORT`
- **host** — when the daemon cannot publish ports (`bridge=none` / `iptables=false`, or no default `bridge` network). Runtime config under `.run/` listens on `SERVER_PORT`.

## TLS / trust

```bash
sudo cp certs/domain.crt /usr/local/share/ca-certificates/registry.crt
sudo update-ca-certificates
sudo systemctl restart docker
```

Or skip verify: `curl -k …`

## Layout

```
config.json   Zot server config (TLS, auth, accessControl)
htpasswd      bcrypt users (make genhtpasswd)
certs/        TLS key + cert
data/         registry storage
.run/         host-mode generated config (gitignored)
```
