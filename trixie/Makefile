BUILD4 ?= /home/cursor/dockers/build4/build4

.PHONY: tools bake build buildx

tools:
	BUILD4="$(BUILD4)" ../common/build-lrm-tools.sh trixie

bake: tools
	docker buildx bake

build: tools
	docker compose build

buildx: tools
	docker buildx build \
		--build-context host_opt=/opt \
		.
