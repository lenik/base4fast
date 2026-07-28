BUILD4 ?= /home/cursor/dockers/build4/build4

.PHONY: tools bake build buildx

# Clone bas-c/getbar/repoman into common/deps/, then build4 for this suite → vendor/
tools:
	BUILD4="$(BUILD4)" ../common/build-lrm-tools.sh buster

bake: tools
	docker buildx bake

build: tools
	docker compose build

buildx: tools
	docker buildx build \
		--build-context host_opt=/opt \
		.
