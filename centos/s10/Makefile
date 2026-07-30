BUILD4 ?= $(shell which build4 || (echo "Error: build4 not found" >&2; exit 1))

.PHONY: tools bake build buildx

tools:
	BUILD4="$(BUILD4)" ../../common/build-lrm-tools.sh centos/s10

bake: tools
	docker buildx bake

build: tools
	docker compose build

buildx: tools
	docker buildx build \
		--build-context host_opt=/opt \
		.
