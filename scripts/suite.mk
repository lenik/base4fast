# Common suite Makefile fragment. Include from <family>/<suite>/Makefile:
#   include ../../scripts/suite.mk
#
# PULL: prefer (default) | never | always   — see scripts/bake-suite.sh

BUILD4 ?= $(shell command -v build4 || (echo "Error: build4 not found" >&2; exit 1))
PULL   ?= prefer
PULL_MAX_AGE ?= 168h
# Override for centos 5/6 stubs: TOOLS_SCRIPT=../../scripts/build-lrm-tools-stub.sh
TOOLS_SCRIPT ?= ../../scripts/build-lrm-tools.sh

# FAMILY/SUITE derived from directory (…/debian/bookworm → debian/bookworm)
SUITE_SPEC := $(patsubst $(abspath $(CURDIR)/../..)/%,%,$(abspath $(CURDIR)))

.PHONY: tools bake build buildx

tools:
	BUILD4="$(BUILD4)" $(TOOLS_SCRIPT) $(SUITE_SPEC)

bake: tools
	SKIP_TOOLS=1 PULL="$(PULL)" PULL_MAX_AGE="$(PULL_MAX_AGE)" \
		../../scripts/bake-suite.sh $(SUITE_SPEC)

build: tools
	docker compose build

buildx: tools
	docker buildx build .
