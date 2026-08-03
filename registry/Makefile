# Local Zot OCI registry (HTTPS API + UI on one port).
# Typical flow:  make gencerts genhtpasswd run
#
# Ports:
#   CONTAINER_PORT (8080) — config.json → http.port
#   SERVER_PORT    (1244) — published on the host
#
# Listen: config http.address "[::]" (all IPv4 + IPv6; Zot joins as [host]:port)
#
# Network modes (NETWORK_MODE=auto|host|bridge):
#   bridge — -p SERVER_PORT:CONTAINER_PORT
#   host   — --network host; runtime config listens on SERVER_PORT
#   auto   — host if daemon can't publish ports, else bridge

SHELL = /bin/bash

# ---------------------------------------------------------------------------
# Identity
# ---------------------------------------------------------------------------

ID = registry
IMAGE = $(ID)
VERSION = latest
GUEST_SHELL = /bin/ash -l

# ---------------------------------------------------------------------------
# Ports: container listen vs host publish
# ---------------------------------------------------------------------------

SERVER_HOST = localhost
SERVER_PORT = 1244
CONTAINER_PORT = 8080

# ---------------------------------------------------------------------------
# Default htpasswd users (bcrypt). Roles enforced in config.json accessControl.
#   lenik — admin (read/create/update/delete on all repos)
#   zot   — normal (read/create/update)
#   guest — guest (read only)
# ---------------------------------------------------------------------------

HTPASSWD = htpasswd
USER_LENIK = lenik
PASS_LENIK = 2Bw1ijPadpTX
USER_ZOT = zot
PASS_ZOT = 2Bw1ijPadpTX
USER_GUEST = guest
PASS_GUEST = V6RiHvGv5a29

# ---------------------------------------------------------------------------
# Network mode: auto | host | bridge
# ---------------------------------------------------------------------------

NETWORK_MODE ?= auto

_DETECT_NETWORK_MODE = $(shell \
	if [ -r /etc/docker/daemon.json ] && \
	   { grep -Eq '"bridge"[[:space:]]*:[[:space:]]*"none"' /etc/docker/daemon.json || \
	     grep -Eq '"iptables"[[:space:]]*:[[:space:]]*false' /etc/docker/daemon.json; }; then \
	  echo host; \
	elif docker network inspect bridge >/dev/null 2>&1; then \
	  echo bridge; \
	else \
	  echo host; \
	fi)

ifeq ($(NETWORK_MODE),auto)
  NET_MODE := $(_DETECT_NETWORK_MODE)
else
  NET_MODE := $(NETWORK_MODE)
endif

ifeq ($(NET_MODE),host)
  DOCKER_NET_OPTS = --network host
  # Host net can't remap ports; use rewritten config that listens on SERVER_PORT.
  ZOT_CONFIG_MOUNT = -v $$(readlink -f .run/config.json):/etc/zot/config.json:ro
else ifeq ($(NET_MODE),bridge)
  DOCKER_NET_OPTS = -p $(SERVER_PORT):$(CONTAINER_PORT)
  ZOT_CONFIG_MOUNT = -v $$(readlink -f config.json):/etc/zot/config.json:ro
else
  $(error NETWORK_MODE must be auto, host, or bridge (got '$(NETWORK_MODE)' → '$(NET_MODE)'))
endif

# ---------------------------------------------------------------------------
# Docker run defaults
# ---------------------------------------------------------------------------

DOCKER_RUN_DNS =
#DOCKER_RUN_DNS = --dns 8.8.8.8

DOCKER_RUN_VOLS = \
    -v /home:/home \
    -v /media:/media \
    -v /mnt:/mnt \
    -v /tmp:/tmp

DOCKER_RUN_OPTS = \
    --hostname $(ID) \
    $(DOCKER_RUN_DNS) \
    $(DOCKER_RUN_VOLS)

# ---------------------------------------------------------------------------
# Zot image & bind mounts (host paths resolved at recipe time)
# ---------------------------------------------------------------------------

ZOT_IMAGE = ghcr.io/project-zot/zot-linux-amd64:v2.1.18
ZOT_DATA = $$(readlink -f data)
ZOT_CONFIG = $$(readlink -f config.json)
ZOT_HTPASSWD = $$(readlink -f $(HTPASSWD))
ZOT_CERTS = $$(readlink -f certs)

# ---------------------------------------------------------------------------
# TLS (self-signed; SAN from certs/domain.cfg → req_extensions)
# ---------------------------------------------------------------------------

CERT_DAYS ?= 18250
CERT_DIR = certs
CERT_CFG = $(CERT_DIR)/domain.cfg
CERT_KEY = $(CERT_DIR)/domain.pem
CERT_CRT = $(CERT_DIR)/domain.crt

gencerts:
	@if [ -f $(CERT_KEY) ] && [ -f $(CERT_CRT) ]; then \
	  echo "already exists: $(CERT_KEY) $(CERT_CRT) (use gencerts-force to regenerate)"; \
	else \
	  $(MAKE) gencerts-force; \
	fi

gencerts-force:
	openssl req -x509 -newkey rsa:4096 -sha256 -nodes -days $(CERT_DAYS) \
	    -config $(CERT_CFG) \
	    -extensions req_extensions \
	    -keyout $(CERT_KEY) \
	    -out $(CERT_CRT)
	@chmod 600 $(CERT_KEY)
	@openssl x509 -in $(CERT_CRT) -noout -subject -dates -ext subjectAltName

# ---------------------------------------------------------------------------
# htpasswd (bcrypt only — required by Zot)
# ---------------------------------------------------------------------------

genhtpasswd:
	@if [ -f $(HTPASSWD) ]; then \
	  echo "already exists: $(HTPASSWD) (use genhtpasswd-force to regenerate)"; \
	else \
	  $(MAKE) genhtpasswd-force; \
	fi

genhtpasswd-force:
	htpasswd -cbB $(HTPASSWD) $(USER_LENIK) '$(PASS_LENIK)'
	htpasswd -bB $(HTPASSWD) $(USER_ZOT) '$(PASS_ZOT)'
	htpasswd -bB $(HTPASSWD) $(USER_GUEST) '$(PASS_GUEST)'
	# Normalize apache2-utils $$2y$$ → $$2a$$ for Go/Zot bcrypt
	sed -i 's/\$$2y\$$/\$$2a\$$/g' $(HTPASSWD)
	@chmod 640 $(HTPASSWD)
	@echo "users: $(USER_LENIK) (admin), $(USER_ZOT) (user), $(USER_GUEST) (guest)"

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

up: -run-docker -tty-cleanup

-run-docker: run-zot

run-zot: genhtpasswd
	@echo "network mode: $(NET_MODE) (NETWORK_MODE=$(NETWORK_MODE))"
	@echo "host $(SERVER_HOST):$(SERVER_PORT) → container :$(CONTAINER_PORT)"
	@if [ "$(NET_MODE)" = host ]; then \
	  mkdir -p .run; \
	  sed -E 's/"port"[[:space:]]*:[[:space:]]*"$(CONTAINER_PORT)"/"port": "$(SERVER_PORT)"/' \
	    config.json > .run/config.json; \
	fi
	docker run $(DOCKER_RUN_OPTS) \
	    -d \
	    --name $(ID) \
	    $(DOCKER_NET_OPTS) \
	    -v $(ZOT_DATA):/var/lib/registry \
	    $(ZOT_CONFIG_MOUNT) \
	    -v $(ZOT_HTPASSWD):/etc/zot/htpasswd:ro \
	    -v $(ZOT_CERTS):/certs:ro \
	    $(ZOT_IMAGE) serve /etc/zot/config.json

start: pre-start -start post-start
-start:
	docker start $(ID)
pre-start:
post-start:

stop: pre-stop -stop post-stop
-stop:
	-docker stop $(ID)
pre-stop:
post-stop:

down: stop rm

rm:
	-docker rm $(ID)

shell: start -shell -tty-cleanup

-shell:
	@docker exec -it $(ID) $(GUEST_SHELL)

-tty-cleanup:
	@settermtitle "IMG $${PWD##*/}"

net-mode:
	@echo $(NET_MODE)

addr:
	@echo $(SERVER_HOST):$(SERVER_PORT)

ip-int:
	@docker inspect --format '{{.NetworkSettings.IPAddress}}' $(ID)
