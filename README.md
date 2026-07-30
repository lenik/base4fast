# base4fast

Base Docker images with China-friendly mirror selection (`getbar` / `lrm bwsel`), core utilities, locales, JDK under `/opt/java`, and a non-root `lenik` SSH user.

## Suites

### Debian (`debian/<suite>/`)

| Directory            | Base image         | Tags                                      |
|----------------------|--------------------|-------------------------------------------|
| `debian/stretch/`    | `debian:stretch`   | `base4fast:stretch`, `base4fast:stretch-VERSION` |
| `debian/buster/`     | `debian:buster`    | `base4fast:buster`, …                     |
| `debian/bullseye/`   | `debian:bullseye`  | `base4fast:bullseye`, …                   |
| `debian/bookworm/`   | `debian:bookworm`  | `base4fast:bookworm`, …                   |
| `debian/trixie/`     | `debian:trixie`    | `base4fast:trixie`, …                     |

EOL stretch/buster bootstrap from CN `debian-archive` (NJU) + archive-security; live suites use `lrm bwsel`.

### Ubuntu LTS (`ubuntu/<suite>/`)

| Directory            | Version | Base image           | Tags |
|----------------------|---------|----------------------|------|
| `ubuntu/xenial/`     | 16.04   | `ubuntu:xenial`      | `base4fast:ubuntu-xenial`, `base4fast:ubuntu-16.04`, …-VERSION |
| `ubuntu/bionic/`     | 18.04   | `ubuntu:bionic`      | `base4fast:ubuntu-bionic`, `base4fast:ubuntu-18.04`, … |
| `ubuntu/focal/`      | 20.04   | `ubuntu:focal`       | `base4fast:ubuntu-focal`, `base4fast:ubuntu-20.04`, … |
| `ubuntu/jammy/`      | 22.04   | `ubuntu:jammy`       | `base4fast:ubuntu-jammy`, `base4fast:ubuntu-22.04`, … |
| `ubuntu/noble/`      | 24.04   | `ubuntu:noble`       | `base4fast:ubuntu-noble`, `base4fast:ubuntu-24.04`, … |
| `ubuntu/resolute/`   | 26.04   | `ubuntu:resolute`    | `base4fast:ubuntu-resolute`, `base4fast:ubuntu-26.04`, … |

EOL xenial/bionic/focal stay on CN `/ubuntu/` mirrors via `lrm bwsel` (not ubuntu-old); jammy+ same.

### CentOS (`centos/<suite>/`)

| Directory       | Base image                         | Tags |
|-----------------|------------------------------------|------|
| `centos/5/`     | `centos:5`                         | `base4fast:centos-5`, … |
| `centos/6/`     | `centos:6`                         | `base4fast:centos-6`, … |
| `centos/7/`     | `centos:7`                         | `base4fast:centos-7`, … |
| `centos/8/`     | `centos:8`                         | `base4fast:centos-8`, … |
| `centos/s9/`    | `quay.io/centos/centos:stream9`    | `base4fast:centos-s9`, `base4fast:centos-s9-VERSION` |
| `centos/s10/`   | `quay.io/centos/centos:stream10`   | `base4fast:centos-s10`, … |

Vault suites (5–8) bootstrap from centos-vault; Stream 9/10 use centos-stream mirrors via `lrm bwsel`.
Host kernel needs `vsyscall=emulate` for CentOS 5/6 bash inside Docker (legacy vsyscall).

Default `VERSION=2.0`.

## Build

Host needs Docker (buildx), [build4](https://github.com/lenik), and git.

```bash
cd ubuntu/jammy     # or debian/bookworm, centos/s9, …
make bake           # builds suite-local vendor/ tools, then docker buildx bake
# or: make build / make buildx
```

`make tools` alone only compiles getbar/lrm into `<family>/<suite>/vendor/` (gitignored). Details: [`common/README.md`](common/README.md).

## Layout

```
debian/<suite>/          # Debian family
ubuntu/<suite>/          # Ubuntu LTS family
centos/<suite>/          # CentOS / Stream family
  Dockerfile             # bootstrap → COPY vendor/ → lrm bwsel → packages
  Makefile               # tools | bake | build | buildx
  docker-bake.hcl
  docker-compose.yml
  authorized_keys
  etc/                   # apt or yum bootstrap + bashrc
  vendor/                # build4 output (not committed)

common/                  # shared build4 helpers, apt-via-lrm / yum-via-lrm
```

JDK is copied from the host via build context `host_opt=/opt`.
