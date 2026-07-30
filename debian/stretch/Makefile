BUILD4 ?= $(shell which build4 || (echo "Error: build4 not found" >&2; exit 1))

.PHONY: tools bake build buildx

# Clone bas-c/getbar/repoman into common/deps/, then build4 for this suite → vendor/
tools:
	BUILD4="$(BUILD4)" ../../common/build-lrm-tools.sh debian/stretch

bake: tools
	docker buildx bake

build: tools
	docker compose build

buildx: tools
	docker buildx build \
		--build-context host_opt=/opt \
		.
