# Shared helpers for base4fast Docker builds (China mirror selection).

Host workflow (per suite, see `<suite>/Makefile`):

1. `make tools` → `common/build-lrm-tools.sh SUITE`
   - git clone bas-c / getbar / repoman into `common/deps/`
   - build4 compiles them against `debian:SUITE`
   - writes `<suite>/vendor/`
2. `make bake` / `make build` → Docker image (`COPY vendor/`, then `lrm bwsel` inside)

Image workflow (Dockerfile):

1. Bootstrap apt from `etc/apt/bootstrap` (no hardcoded mirrors in Dockerfile)
2. `COPY vendor/` (suite-specific getbar/lrm from build4)
3. `lrm bwsel` inside the image
4. apt-get update/upgrade + remaining packages
   - EOL (stretch/buster): also enable `archive-security.list`

Suites: stretch, buster (archive), bullseye, bookworm, trixie (live mirrors).

Requirements on the host: Docker, build4, git.
