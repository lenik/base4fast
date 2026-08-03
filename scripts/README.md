# Shared helpers for base4fast Docker builds (China mirror selection).

Host workflow (per suite, see `<family>/<suite>/Makefile`):

1. `make tools` → `scripts/build-lrm-tools.sh FAMILY/SUITE`
   - uses `extern/` clones read-only (clone once; set `VENDOR_UPDATE=1` to refresh from GitHub)
   - deps: `getbar`, `repoman`, `bas-c`, `includes` (for bas-c unit-test discovery), optional `subprojects/`
   - build4 compiles getbar/lrm against the suite target image for each `ARCH` (`amd64` / `arm64`)
   - writes `<family>/<suite>/build-<arch>/`
2. `make bake` / `make build` → Docker image (`COPY build-${TARGETARCH}/`, then `lrm bwsel` inside)

Host bas-c tests need the `includes` CLI on `PATH` (system package, or a local build of `extern/includes`).

## Debian / Ubuntu image workflow

1. Bootstrap apt from `etc/apt/bootstrap` (no hardcoded mirrors in Dockerfile); install `curl`
2. `COPY build-${TARGETARCH}/` (suite-specific getbar/lrm from build4)
3. `configrepo.sh` → local ISO mirror (`iso-sources`, soft-skip if suite missing)
4. `apt-via-lrm.sh` → `lrm bwsel` inside the image
5. apt-get update/upgrade + remaining packages + `install-net-tools.sh`
   - EOL Debian (stretch/buster): also enable `archive-security.list`
   - EOL Ubuntu (xenial/bionic/focal): regular `/ubuntu/` mirrors via lrm (not ubuntu-old)

Suites: `debian/{stretch,buster,bullseye,bookworm,trixie,stable,testing,sid}`,
`ubuntu/{xenial,bionic,focal,jammy,noble,resolute}`.
loong64 tools/images: `sid` (local `debian:sid-loong64`), `trixie`/`stable`/`testing` via `ghcr.io/loong64/debian`.

Ubuntu tags: `b4f-ubuntu:<codename>` / `b4f-ubuntu:<YY.MM>` (symbol), `…-<arch>` (arch alias), `…-<VERSION>-<arch>` (versioned).

## CentOS image workflow

1. Bootstrap yum/dnf from `etc/yum/bootstrap/lrm-bootstrap.repo`
2. `COPY vendor/`
3. `yum-via-lrm.sh` → `lrm bwsel` inside the image
4. yum/dnf upgrade + remaining packages

Suites: `centos/{5,6,7,8,s9,s10}` (`s9`/`s10` = CentOS Stream 9/10).
Tags: `b4f-centos:<suite>` (symbol), `…-<arch>` (alias), `…-VERSION-ARCH` (versioned).
Host kernel needs `vsyscall=emulate` for CentOS 5/6 (legacy vsyscall for old glibc/bash).
CentOS 5/6 use `build-lrm-tools-stub.sh` + fixed HTTP vault mirrors (no Meson/bwsel; glibc too old for EL7+ getbar/lrm).

## Rocky Linux image workflow

Same as CentOS (dnf + `yum-via-lrm.sh`, `DISTRO_SPEC=rocky:N`).
Suites: `rocky/{8,9,10}`. Tags: `b4f-rocky:<N>` (symbol), `…-<arch>` (alias), `…-VERSION-ARCH` (versioned).
Base images: `quay.io/rockylinux/rockylinux:<N>`.

## openEuler image workflow

Same as CentOS/Rocky (dnf + `yum-via-lrm.sh`, `DISTRO_SPEC=openeuler:YY.MM`).
Suites: `openeuler/{20.03,22.03,24.03}`. Tags: `b4f-openeuler:<YY.MM>` (symbol), `…-<arch>` (alias), `…-VERSION-ARCH` (versioned).
Base images: `openeuler/openeuler:<YY.MM>`.
loong64: `24.03` from Hub multi-arch; `22.03` via local `openeuler/openeuler:22.03-loong64` (docker_img import); `20.03` skipped (no OS/loongarch64).
Alternate loong64 base: `ghcr.io/loong64/openeuler:24` ([loong64/container-images](https://github.com/loong64/container-images)).
Requires repoman openEuler support (`openEuler-YY.MM-LTS/{OS,everything,update}`, full `YY.MM` releasever, `loongarch64` basearch). Local `extern/repoman` carries these fixes until published upstream.

## SLES image workflow

1. Bootstrap zypper from `etc/zypp/bootstrap/lrm-bootstrap.repo` (China openSUSE mirrors; no SCC)
2. `COPY vendor/`
3. `zypper-via-lrm.sh` → `lrm bwsel` (openSUSE/SLES zypper backend)
4. zypper refresh/update + remaining packages

Suites: `sles/{11,12,15.1,16.1}`.
Tags: `b4f-sles:<suite>` (symbol), `…-<arch>` (alias), `…-VERSION-ARCH` (versioned).
Notes:
- `15.1` = SLES 15 SP1 era via `opensuse/leap:15.1` (BCI `:15.1` retired)
- `16.1` = `registry.suse.com/bci/bci-base:16.1`
- `12` = `registry.suse.com/suse/sles12sp5` + Leap 42.3 package mirrors
- `11` = `opensuse/13.2` twin (official SLES11 containers are not redistributable)

## Local ISO mirror (`configrepo`)

Before `lrm bwsel`, images run `configrepo` (from `iso-sources/ROOT/`, copied into `build-<arch>/bin/`).
Default host: `183.131.83.99:1506`. Discovers suites by parsing directory indexes and writes
`configrepo.list` / `configrepo.sources` / `configrepo.repo` (not `kolla1-local.*`).
Host: `cd /home/docker/iso-sources && make ensure-isos` (mount `/img/iso/*.iso` + `make symlinks`).

## Docker proxy vs container traffic

Dockerd systemd `HTTP_PROXY` is for **registry pulls** only. `bake-suite.sh` clears client
proxy env and bake `HTTP(S)_PROXY` args; Dockerfiles also `ENV HTTP_PROXY=` so RUN steps
do not send traffic through the pull proxy.

## Scripts

| Script | Role |
|--------|------|
| `build-lrm-tools.sh` | Host: build4 getbar/lrm into `build-<arch>/` |
| `build4-prescript.sh` | Inside build4 (Debian/Ubuntu): apt toolchain |
| `build4-prescript-rpm.sh` | Inside build4 (CentOS/Rocky/openEuler): yum/dnf toolchain |
| `build4-inside.sh` | Inside build4: meson compile |
| `configrepo.sh` / `configrepo` | Inside image: local ISO apt/yum before bwsel |
| `install-net-tools.sh` | Inside image: ping/curl/nmap/… (skip missing pkgs) |
| `apt-via-lrm.sh` | Inside Debian/Ubuntu image: bwsel + apt update |
| `yum-via-lrm.sh` | Inside CentOS/Rocky/openEuler image: bwsel + yum/dnf makecache |
| `zypper-via-lrm.sh` | Inside SLES image: bwsel + zypper refresh |
| `build4-prescript-zypper.sh` | Inside build4 (SLES): zypper toolchain |
| `apt-bootstrap-ca.sh` | Inside Debian/Ubuntu image: CA store over HTTP if needed |

Requirements on the host: Docker, build4, git.
