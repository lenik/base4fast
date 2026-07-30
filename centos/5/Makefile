BUILD4 ?= $(shell which build4 || (echo "Error: build4 not found" >&2; exit 1))

.PHONY: tools bake build buildx

# CentOS 5 has no usable Python3/Meson; getbar/lrm from EL7+ need newer glibc.
# Stub vendor + fixed HTTP vault mirrors (see Dockerfile).
tools:
	../../common/build-lrm-tools-stub.sh centos/5

bake: tools
	docker buildx bake

build: tools
	docker compose build

buildx: tools
	docker buildx build \
		--build-context host_opt=/opt \
		.
