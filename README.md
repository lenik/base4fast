# base4fast

Base Docker images with China-friendly mirror selection (`getbar` / `lrm bwsel`) and a non-root `lenik` SSH user. Debian/Ubuntu images install only getbar/lrm runtime deps (no locales/timezone setup). `make bake` builds `linux/amd64` and `linux/arm64`.

Image naming (default `VERSION=1.0`):

| Kind | Example |
|------|---------|
| Symbol (multi-arch) | `b4f-debian:trixie` |
| Arch alias | `b4f-debian:trixie-amd64` |
| Versioned + arch | `b4f-debian:trixie-1.0-amd64` |

## Suites

### Debian (`debian/<suite>/`)

| Directory            | Base image                         | Tags                                      |
|----------------------|------------------------------------|-------------------------------------------|
| `debian/stretch/`    | `debian:stretch` / `-slim`         | `b4f-debian:stretch`, `b4f-debian:stretch-1.0-amd64`, …-slim |
| `debian/buster/`     | `debian:buster` / `-slim`          | `b4f-debian:buster`, … |
| `debian/bullseye/`   | `debian:bullseye` / `-slim`        | `b4f-debian:bullseye`, … |
| `debian/bookworm/`   | `debian:bookworm` / `-slim`        | `b4f-debian:bookworm`, … |
| `debian/trixie/`     | `debian:trixie` / `-slim`          | `b4f-debian:trixie`, `b4f-debian:trixie-amd64`, `b4f-debian:trixie-1.0-amd64`, … |
| `debian/stable/`     | `debian:stable` / `-slim`          | `b4f-debian:stable`, … (+ `…-loong64` via ghcr trixie) |
| `debian/testing/`    | `debian:testing` / `-slim`         | `b4f-debian:testing`, … (+ `…-loong64` via ghcr forky) |
| `debian/sid/`        | `debian:sid` / `-slim`             | `b4f-debian:sid`, `b4f-debian:sid-loong64`, … |

`make bake` builds both the full and `-slim` targets (same Dockerfile, `BASE_IMAGE` arg). EOL stretch/buster bootstrap from CN `debian-archive` (NJU) + archive-security; live suites use `lrm bwsel`.

**loong64:** `b4f-debian:sid-loong64` uses a local `debian:sid-loong64` import. `trixie` / `stable` / `testing` loong64 (and `-slim`) pull from [`ghcr.io/loong64/debian`](https://github.com/loong64/docker-library) (`trixie`, `trixie-slim`, `forky`, `forky-slim`; ghcr login may be required). Apt stays on loong64-capable mirrors (`mirrors.loong64.com` for trixie/stable; Aliyun `sid` for testing/forky) — regular CN debian mirrors are skipped by `apt-via-lrm` on loong64. There is no bookworm loong64 image.

### Ubuntu LTS (`ubuntu/<suite>/`)

| Directory            | Version | Base image           | Tags |
|----------------------|---------|----------------------|------|
| `ubuntu/xenial/`     | 16.04   | `ubuntu:xenial`      | `b4f-ubuntu:xenial`, `b4f-ubuntu:16.04`, …-VERSION-ARCH |
| `ubuntu/bionic/`     | 18.04   | `ubuntu:bionic`      | `b4f-ubuntu:bionic`, `b4f-ubuntu:18.04`, … |
| `ubuntu/focal/`      | 20.04   | `ubuntu:focal`       | `b4f-ubuntu:focal`, `b4f-ubuntu:20.04`, … |
| `ubuntu/jammy/`      | 22.04   | `ubuntu:jammy`       | `b4f-ubuntu:jammy`, `b4f-ubuntu:22.04`, … |
| `ubuntu/noble/`      | 24.04   | `ubuntu:noble`       | `b4f-ubuntu:noble`, `b4f-ubuntu:24.04`, … |
| `ubuntu/resolute/`   | 26.04   | `ubuntu:resolute`    | `b4f-ubuntu:resolute`, `b4f-ubuntu:26.04`, … |

EOL xenial/bionic/focal stay on CN `/ubuntu/` mirrors via `lrm bwsel` (not ubuntu-old); jammy+ same. (No official Ubuntu `-slim` tags.)


### CentOS (`centos/<suite>/`)

| Directory       | Base image                         | Tags |
|-----------------|------------------------------------|------|
| `centos/5/`     | `centos:5`                         | `b4f-centos:5`, … (amd64 only) |
| `centos/6/`     | `centos:6`                         | `b4f-centos:6`, … (amd64 only) |
| `centos/7/`     | `centos:7`                         | `b4f-centos:7`, … (amd64 only) |
| `centos/8/`     | `quay.io/centos/centos:8`           | `b4f-centos:8-{amd64,arm64}`, … |
| `centos/s9/`    | `quay.io/centos/centos:stream9`    | `b4f-centos:s9-{amd64,arm64}`, … |
| `centos/s10/`   | `quay.io/centos/centos:stream10`   | `b4f-centos:s10-{amd64,arm64}`, … |

Vault suites (5–8) bootstrap from centos-vault; Stream 9/10 use centos-stream mirrors via `lrm bwsel`.
`make bake` builds `linux/amd64` + `linux/arm64` for 8/s9/s10 (no official arm64 base for 5–7).
Host kernel needs `vsyscall=emulate` for CentOS 5/6 bash inside Docker (legacy vsyscall).

### openEuler (`openeuler/<suite>/`)

| Directory           | Base image                     | Tags |
|---------------------|--------------------------------|------|
| `openeuler/20.03/`  | `openeuler/openeuler:20.03`    | `b4f-openeuler:20.03`, `…-amd64`, `…-1.0-amd64` (amd64/arm64) |
| `openeuler/22.03/`  | `openeuler/openeuler:22.03`    | `b4f-openeuler:22.03`, … (+ `…-loong64` via local docker_img import) |
| `openeuler/24.03/`  | `openeuler/openeuler:24.03`    | `b4f-openeuler:24.03`, … (+ `…-loong64` from Hub multi-arch) |

`make bake` builds `linux/amd64` and `linux/arm64`. openEuler 20.03 has no `OS/loongarch64` tree (loong64 skipped). 24.03 Hub tags include `linux/loong64`; alternate base [`ghcr.io/loong64/openeuler:24`](https://github.com/loong64/container-images). 22.03 loong64 needs a local import of the official `docker_img` tarball (Hub has no loong64 for that tag):

```bash
curl -LO https://mirrors.tuna.tsinghua.edu.cn/openeuler/openEuler-22.03-LTS/docker_img/loongarch64/openEuler-docker.loongarch64.tar.xz
img=$(docker load -i openEuler-docker.loongarch64.tar.xz | awk '/Loaded image/{print $NF}')
docker tag "$img" openeuler/openeuler:22.03-loong64
# then: ARCHES="amd64 arm64 loong64" make bake
```

## Build

Host needs Docker (buildx), [build4](https://github.com/lenik), and git.

**Per suite:**

```bash
cd ubuntu/jammy     # or debian/bookworm, centos/s9, openeuler/24.03, …
make bake           # builds suite-local tools, then docker buildx bake
# or: make build / make buildx
```

**Repo root** (`make help`):

```bash
make build-all              # every family/suite
make build-debian           # one family
make build-amd64            # one arch across all suites
make build-debian-loong64   # family + arch
make list-suites
# KEEP_GOING=1 or FAIL_FAST=0 — continue after a suite failure
# PULL=prefer|never|always — base-image Hub policy (default prefer):
#   prefer: use local if younger than PULL_MAX_AGE (default 168h);
#           otherwise try Hub, fall back to local on timeout
#   never:  never contact Hub for bases (local cache only)
#   always: always ask Hub; fall back to local on timeout
```

`make tools` alone compiles getbar/lrm from `extern/` into `<family>/<suite>/build-<arch>/` for `amd64` and `arm64` (gitignored). Details: [`scripts/README.md`](scripts/README.md).

Images run `configrepo` (local ISO mirror at `183.131.83.99:1506`) before `lrm bwsel`, then `install-net-tools.sh` (ping/curl/nmap/…; missing packages skipped). Prepare ISOs with `make -C /home/docker/iso-sources ensure-isos`. Dockerd `HTTP_PROXY` stays for image pulls; bake clears it for build/RUN network.

## Layout

```
debian/<suite>/          # Debian family
ubuntu/<suite>/          # Ubuntu LTS family
centos/<suite>/          # CentOS / Stream family
openeuler/<suite>/       # openEuler LTS family
  Dockerfile             # bootstrap → COPY vendor/ → lrm bwsel → packages
  Makefile               # tools | bake | build | buildx
  docker-bake.hcl
  docker-compose.yml
  authorized_keys
  etc/                   # apt or yum bootstrap + bashrc
  vendor/                # legacy (migrated to build-<arch>/)
  build-<arch>/          # build4 output per arch (not committed)

scripts/                 # shared build4 helpers, apt-via-lrm / yum-via-lrm
```
