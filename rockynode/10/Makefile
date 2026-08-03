# BASE_IMAGE may include a registry namespace (FROM parent) — pull is enabled.
# IMAGE (rockynode) is always a local short tag — no registry prefix.

BASE_IMAGE ?= 183.131.83.99:1244/b4f-rocky:10
IMAGE ?= b4f-rockynode:10
VERSION ?= 1.0-snapshot

BUILD_OPTS = --provenance=false --sbom=false --shm-size=256m

.PHONY: prebuild bake build buildx

prebuild:
	./prebuild.sh

bake: prebuild
	BASE_IMAGE=$(BASE_IMAGE) VERSION=$(VERSION) docker buildx bake

build: prebuild
	docker build $(BUILD_OPTS) \
		--build-arg BASE_IMAGE=$(BASE_IMAGE) \
		-t $(IMAGE) \
		-t $(IMAGE)-$(VERSION) \
		.

buildx: prebuild
	docker buildx build $(BUILD_OPTS) \
		--build-arg BASE_IMAGE=$(BASE_IMAGE) \
		-t $(IMAGE) \
		-t $(IMAGE)-$(VERSION) \
		--load \
		.
