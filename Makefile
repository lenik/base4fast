# base4fast — top-level build orchestration
#
#   make build-all                 # every family / suite
#   make build-debian              # one family
#   make build-amd64               # one arch across all suites
#   make build-debian-loong64      # family + arch
#   make list-suites
#
# Vars: BUILD4, FAIL_FAST=0|1 (default 1),
#       PULL=prefer|never|always (default prefer — try Hub, fall back to local),
#       KEEP_GOING=1 (= FAIL_FAST=0)

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c

FAMILIES := debian ubuntu centos rocky sles openeuler
ARCHES   := amd64 arm64 loong64

BUILD4     ?= $(shell command -v build4 2>/dev/null || true)
FAIL_FAST  ?= 1
# prefer: attempt Hub; on timeout/auth errors reuse local cache (even if stale).
# never:  never hit Hub for bases.  always: require Hub.
PULL         ?= prefer
PULL_MAX_AGE ?= 168h
KEEP_GOING   ?= 0

ifeq ($(KEEP_GOING),1)
  FAIL_FAST := 0
endif

export BUILD4 FAIL_FAST PULL PULL_MAX_AGE

debian_SUITES    := $(sort $(patsubst debian/%/docker-bake.hcl,%,$(wildcard debian/*/docker-bake.hcl)))
ubuntu_SUITES    := $(sort $(patsubst ubuntu/%/docker-bake.hcl,%,$(wildcard ubuntu/*/docker-bake.hcl)))
centos_SUITES    := $(sort $(patsubst centos/%/docker-bake.hcl,%,$(wildcard centos/*/docker-bake.hcl)))
rocky_SUITES     := $(sort $(patsubst rocky/%/docker-bake.hcl,%,$(wildcard rocky/*/docker-bake.hcl)))
sles_SUITES      := $(sort $(patsubst sles/%/docker-bake.hcl,%,$(wildcard sles/*/docker-bake.hcl)))
openeuler_SUITES := $(sort $(patsubst openeuler/%/docker-bake.hcl,%,$(wildcard openeuler/*/docker-bake.hcl)))

ALL_SUITES := \
	$(addprefix debian/,$(debian_SUITES)) \
	$(addprefix ubuntu/,$(ubuntu_SUITES)) \
	$(addprefix centos/,$(centos_SUITES)) \
	$(addprefix rocky/,$(rocky_SUITES)) \
	$(addprefix sles/,$(sles_SUITES)) \
	$(addprefix openeuler/,$(openeuler_SUITES))

BAKE_SUITE := $(ROOT)/scripts/bake-suite.sh

.PHONY: help list-suites build-all bake-combo \
	$(addprefix build-,$(FAMILIES)) \
	$(addprefix build-,$(ARCHES)) \
	$(foreach f,$(FAMILIES),$(foreach a,$(ARCHES),build-$(f)-$(a)))

help:
	@echo "base4fast top-level targets"
	@echo ""
	@echo "  build-all                 every suite (all arches in each bake file)"
	@echo "  build-FAMILY              debian ubuntu centos rocky sles openeuler"
	@echo "  build-ARCH                amd64 arm64 loong64"
	@echo "  build-FAMILY-ARCH         e.g. build-debian-loong64"
	@echo "  list-suites               discovered FAMILY/SUITE paths"
	@echo ""
	@echo "Vars: BUILD4 FAIL_FAST=0|1 KEEP_GOING=1"
	@echo "      PULL=prefer|never|always (default prefer)"
	@echo "      PULL_MAX_AGE=168h  (prefer: skip Hub if local bases younger)"
	@echo ""
	@$(MAKE) -s list-suites

list-suites:
	@echo "debian:    $(debian_SUITES)"
	@echo "ubuntu:    $(ubuntu_SUITES)"
	@echo "centos:    $(centos_SUITES)"
	@echo "rocky:     $(rocky_SUITES)"
	@echo "sles:      $(sles_SUITES)"
	@echo "openeuler: $(openeuler_SUITES)"

# Internal: FAMILY=… [ARCH=…] SUITES="a b c"
bake-combo:
	@ok=0; fail=0; \
	for s in $(SUITES); do \
	  spec="$(FAMILY)/$$s"; \
	  echo ""; \
	  if [[ -n "$(ARCH)" ]]; then \
	    echo "======== BUILD $$spec ARCH=$(ARCH) ========"; \
	    args=("$$spec" "$(ARCH)"); \
	  else \
	    echo "======== BUILD $$spec ========"; \
	    args=("$$spec"); \
	  fi; \
	  if $(BAKE_SUITE) "$${args[@]}"; then \
	    ok=$$((ok+1)); \
	  else \
	    fail=$$((fail+1)); \
	    if [[ "$(FAIL_FAST)" == "1" ]]; then \
	      echo "FAIL_FAST: stopping (ok=$$ok fail=$$fail)"; \
	      exit 1; \
	    fi; \
	  fi; \
	done; \
	label="build-$(FAMILY)$(if $(ARCH),-$(ARCH),)"; \
	echo ""; \
	echo "DONE $$label ok=$$ok fail=$$fail"; \
	[[ $$fail -eq 0 ]]

build-debian:    ; @$(MAKE) bake-combo FAMILY=debian    SUITES="$(debian_SUITES)"
build-ubuntu:    ; @$(MAKE) bake-combo FAMILY=ubuntu    SUITES="$(ubuntu_SUITES)"
build-centos:    ; @$(MAKE) bake-combo FAMILY=centos    SUITES="$(centos_SUITES)"
build-rocky:     ; @$(MAKE) bake-combo FAMILY=rocky     SUITES="$(rocky_SUITES)"
build-sles:      ; @$(MAKE) bake-combo FAMILY=sles      SUITES="$(sles_SUITES)"
build-openeuler: ; @$(MAKE) bake-combo FAMILY=openeuler SUITES="$(openeuler_SUITES)"

build-amd64:
	@$(MAKE) bake-arch ARCH=amd64

build-arm64:
	@$(MAKE) bake-arch ARCH=arm64

build-loong64:
	@$(MAKE) bake-arch ARCH=loong64

.PHONY: bake-arch
bake-arch:
	@ok=0; fail=0; \
	for spec in $(ALL_SUITES); do \
	  echo ""; \
	  echo "======== BUILD $$spec ARCH=$(ARCH) ========"; \
	  if $(BAKE_SUITE) "$$spec" "$(ARCH)"; then \
	    ok=$$((ok+1)); \
	  else \
	    fail=$$((fail+1)); \
	    if [[ "$(FAIL_FAST)" == "1" ]]; then \
	      echo "FAIL_FAST: stopping (ok=$$ok fail=$$fail)"; \
	      exit 1; \
	    fi; \
	  fi; \
	done; \
	echo ""; \
	echo "DONE build-$(ARCH) ok=$$ok fail=$$fail"; \
	[[ $$fail -eq 0 ]]

build-debian-amd64:    ; @$(MAKE) bake-combo FAMILY=debian    ARCH=amd64    SUITES="$(debian_SUITES)"
build-debian-arm64:    ; @$(MAKE) bake-combo FAMILY=debian    ARCH=arm64    SUITES="$(debian_SUITES)"
build-debian-loong64:  ; @$(MAKE) bake-combo FAMILY=debian    ARCH=loong64  SUITES="$(debian_SUITES)"
build-ubuntu-amd64:    ; @$(MAKE) bake-combo FAMILY=ubuntu    ARCH=amd64    SUITES="$(ubuntu_SUITES)"
build-ubuntu-arm64:    ; @$(MAKE) bake-combo FAMILY=ubuntu    ARCH=arm64    SUITES="$(ubuntu_SUITES)"
build-ubuntu-loong64:  ; @$(MAKE) bake-combo FAMILY=ubuntu    ARCH=loong64  SUITES="$(ubuntu_SUITES)"
build-centos-amd64:    ; @$(MAKE) bake-combo FAMILY=centos    ARCH=amd64    SUITES="$(centos_SUITES)"
build-centos-arm64:    ; @$(MAKE) bake-combo FAMILY=centos    ARCH=arm64    SUITES="$(centos_SUITES)"
build-centos-loong64:  ; @$(MAKE) bake-combo FAMILY=centos    ARCH=loong64  SUITES="$(centos_SUITES)"
build-rocky-amd64:     ; @$(MAKE) bake-combo FAMILY=rocky     ARCH=amd64    SUITES="$(rocky_SUITES)"
build-rocky-arm64:     ; @$(MAKE) bake-combo FAMILY=rocky     ARCH=arm64    SUITES="$(rocky_SUITES)"
build-rocky-loong64:   ; @$(MAKE) bake-combo FAMILY=rocky     ARCH=loong64  SUITES="$(rocky_SUITES)"
build-sles-amd64:      ; @$(MAKE) bake-combo FAMILY=sles      ARCH=amd64    SUITES="$(sles_SUITES)"
build-sles-arm64:      ; @$(MAKE) bake-combo FAMILY=sles      ARCH=arm64    SUITES="$(sles_SUITES)"
build-sles-loong64:    ; @$(MAKE) bake-combo FAMILY=sles      ARCH=loong64  SUITES="$(sles_SUITES)"
build-openeuler-amd64:   ; @$(MAKE) bake-combo FAMILY=openeuler ARCH=amd64   SUITES="$(openeuler_SUITES)"
build-openeuler-arm64:   ; @$(MAKE) bake-combo FAMILY=openeuler ARCH=arm64   SUITES="$(openeuler_SUITES)"
build-openeuler-loong64: ; @$(MAKE) bake-combo FAMILY=openeuler ARCH=loong64 SUITES="$(openeuler_SUITES)"

build-all:
	@ok=0; fail=0; \
	for spec in $(ALL_SUITES); do \
	  echo ""; \
	  echo "======== BUILD $$spec ========"; \
	  if $(BAKE_SUITE) "$$spec"; then \
	    ok=$$((ok+1)); \
	  else \
	    fail=$$((fail+1)); \
	    if [[ "$(FAIL_FAST)" == "1" ]]; then \
	      echo "FAIL_FAST: stopping (ok=$$ok fail=$$fail)"; \
	      exit 1; \
	    fi; \
	  fi; \
	done; \
	echo ""; \
	echo "DONE build-all ok=$$ok fail=$$fail"; \
	[[ $$fail -eq 0 ]]
