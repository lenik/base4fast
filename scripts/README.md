# Shared helpers for base4fast Docker builds (China mirror selection).

Host workflow (per suite, see `<family>/<suite>/Makefile`):

1. `make tools` → `common/build-lrm-tools.sh FAMILY/SUITE`
   - uses `vendor/` clones read-only (clone once; set `VENDOR_UPDATE=1` to refresh from GitHub)
   - deps: `getbar`, `repoman`, `bas-c`, `includes` (for bas-c unit-test discovery), optional `subprojects/`
   - build4 compiles getbar/lrm against the suite target image
   - writes `<family>/<suite>/vendor/`
2. `make bake` / `make build` → Docker image (`COPY vendor/`, then `lrm bwsel` inside)

Host bas-c tests (`ninja -C vendor/bas-c/build test`) need the `includes`
CLI on `PATH` (system package, or build/install `vendor/includes`).

## Debian / Ubuntu image workflow

1. Bootstrap apt from `etc/apt/bootstrap` (no hardcoded mirrors in Dockerfile)
2. `COPY vendor/` (suite-specific getbar/lrm from build4)
3. `apt-via-lrm.sh` → `lrm bwsel` inside the image
4. apt-get update/upgrade + remaining packages
   - EOL Debian (stretch/buster): also enable `archive-security.list`
   - EOL Ubuntu (xenial/bionic/focal): regular `/ubuntu/` mirrors via lrm (not ubuntu-old)

Suites: `debian/{stretch,buster,bullseye,bookworm,trixie}`,
`ubuntu/{xenial,bionic,focal,jammy,noble,resolute}`.

Ubuntu tags: `base4fast:ubuntu-<codename>` and `base4fast:ubuntu-<YY.MM>` (+ `-VERSION`).

## CentOS image workflow

1. Bootstrap yum/dnf from `etc/yum/bootstrap/lrm-bootstrap.repo`
2. `COPY vendor/`
3. `yum-via-lrm.sh` → `lrm bwsel` inside the image
4. yum/dnf upgrade + remaining packages

Suites: `centos/{5,6,7,8,s9,s10}` (`s9`/`s10` = CentOS Stream 9/10).
Tags: `base4fast:centos-<suite>` and `base4fast:centos-<suite>-VERSION`.
Host kernel needs `vsyscall=emulate` for CentOS 5/6 (legacy vsyscall for old glibc/bash).
CentOS 5/6 use `build-lrm-tools-stub.sh` + fixed HTTP vault mirrors (no Meson/bwsel; glibc too old for EL7+ getbar/lrm).

## Rocky Linux image workflow

Same as CentOS (dnf + `yum-via-lrm.sh`, `DISTRO_SPEC=rocky:N`).
Suites: `rocky/{8,9,10}`. Tags: `base4fast:rocky-<N>` (+ `-VERSION`).
Base images: `quay.io/rockylinux/rockylinux:<N>`.

## SLES image workflow

1. Bootstrap zypper from `etc/zypp/bootstrap/lrm-bootstrap.repo` (China openSUSE mirrors; no SCC)
2. `COPY vendor/`
3. `zypper-via-lrm.sh` → `lrm bwsel` (openSUSE/SLES zypper backend)
4. zypper refresh/update + remaining packages

Suites: `sles/{11,12,15.1,16.1}`.
Tags: `base4fast:sles-<suite>` (+ `-VERSION`).
Notes:
- `15.1` = SLES 15 SP1 era via `opensuse/leap:15.1` (BCI `:15.1` retired)
- `16.1` = `registry.suse.com/bci/bci-base:16.1`
- `12` = `registry.suse.com/suse/sles12sp5` + Leap 42.3 package mirrors
- `11` = `opensuse/13.2` twin (official SLES11 containers are not redistributable)

## Scripts

| Script | Role |
|--------|------|
| `build-lrm-tools.sh` | Host: build4 getbar/lrm into `vendor/` |
| `build4-prescript.sh` | Inside build4 (Debian/Ubuntu): apt toolchain |
| `build4-prescript-rpm.sh` | Inside build4 (CentOS/Rocky): yum/dnf toolchain |
| `build4-inside.sh` | Inside build4: meson compile |
| `apt-via-lrm.sh` | Inside Debian/Ubuntu image: bwsel + apt update |
| `yum-via-lrm.sh` | Inside CentOS/Rocky image: bwsel + yum/dnf makecache |
| `zypper-via-lrm.sh` | Inside SLES image: bwsel + zypper refresh |
| `build4-prescript-zypper.sh` | Inside build4 (SLES): zypper toolchain |
| `apt-bootstrap-ca.sh` | Inside Debian/Ubuntu image: CA store over HTTP if needed |

Requirements on the host: Docker, build4, git.
