BUILD4 ?= $(shell which build4 || (echo "Error: build4 not found" >&2; exit 1))

.PHONY: tools bake build buildx

# CentOS 6 Python is 2.6 — Meson needs ≥3.5; EL7+ getbar/lrm need glibc 2.17+.
# Stub vendor + fixed HTTP vault mirrors (see Dockerfile).
tools:
	../../common/build-lrm-tools-stub.sh centos/6

bake: tools
	docker buildx bake

build: tools
	docker compose build

buildx: tools
	docker buildx build \
		--build-context host_opt=/opt \
		.
