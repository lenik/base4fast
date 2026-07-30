include docker/container.mk

ID = zot
GUEST_SHELL = /bin/ash -l

SERVER_HOST = localhost
SERVER_PORT = 3244
# Zot serves API + UI on the same port (HTTPS).
WEB_PORT = $(SERVER_PORT)

ZOT_IMAGE = ghcr.io/project-zot/zot-linux-amd64:v2.1.18
ZOT_DATA = $$(readlink -f data)
ZOT_CONFIG = $$(readlink -f zot)/config.json
LEGACY_PORT = 3245

# s1/kolla: daemon.json has bridge=none + iptables=false, so -p publishing
# does not work. Use host network and listen on SERVER_PORT directly.

-run-docker: run-zot

run-zot:
	docker run $(DOCKER_RUN_OPTS) \
	    -d \
	    --name $(ID) \
	    --network host \
	    -v $(ZOT_DATA):/var/lib/registry \
	    -v $$(readlink -f zot):/etc/zot:ro \
	    -v $$(readlink -f certs):/certs:ro \
	    $(ZOT_IMAGE) serve /etc/zot/config.json

# One-shot: move distribution registry to LEGACY_PORT and sync into Zot.
migrate-zot:
	-docker rm -f $(ID)-web
	-docker rm -f $(ID)-legacy
	docker rm -f $(ID)
	docker run $(DOCKER_RUN_OPTS) \
	    -d \
	    --name $(ID)-legacy \
	    --network host \
	    -v $$(readlink -f data):/var/lib/registry \
	    -v $$(readlink -f certs):/certs \
	    -e REGISTRY_HTTP_ADDR=0.0.0.0:$(LEGACY_PORT) \
	    -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
	    -e REGISTRY_HTTP_TLS_KEY=/certs/domain.pem \
	    -e REGISTRY_HTTP_TLS_MINIMUMTLS=tls1.0 \
	    -e 'REGISTRY_HTTP_TLS_CIPHERSUITES=["TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256","TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA","TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA","TLS_RSA_WITH_AES_128_CBC_SHA","TLS_RSA_WITH_AES_256_CBC_SHA","TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256","TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"]' \
	    registry:2
	mkdir -p $$(readlink -f data-zot)
	docker run $(DOCKER_RUN_OPTS) \
	    -d \
	    --name $(ID) \
	    --network host \
	    -v $(ZOT_DATA):/var/lib/registry \
	    -v $$(readlink -f zot):/etc/zot:ro \
	    -v $$(readlink -f certs):/certs:ro \
	    $(ZOT_IMAGE) serve /etc/zot/config-migrate.json
	@echo "Zot syncing from legacy registry on :$(LEGACY_PORT)."
	@echo "Watch: make migrate-status"
	@echo "When catalogs match: make migrate-finish"

migrate-status:
	@echo -n "legacy: "; curl -sk https://127.0.0.1:$(LEGACY_PORT)/v2/_catalog | python3 -c 'import sys,json; print(len(json.load(sys.stdin).get("repositories",[])))'
	@echo -n "zot:    "; curl -sk https://127.0.0.1:$(SERVER_PORT)/v2/_catalog | python3 -c 'import sys,json; print(len(json.load(sys.stdin).get("repositories",[])))'
	@docker logs --tail 30 $(ID) 2>&1 | grep -iE 'sync|error|fail' | tail -20 || true

# Compare every repo's tags (run before migrate-finish).
migrate-verify:
	@python3 -c 'import json,urllib.request,ssl; ctx=ssl._create_unverified_context();\
get=lambda u: json.load(urllib.request.urlopen(u, context=ctx));\
leg=get("https://127.0.0.1:$(LEGACY_PORT)/v2/_catalog")["repositories"]; bad=[];\
\
[bad.append((r,sorted(set(get("https://127.0.0.1:$(LEGACY_PORT)/v2/%s/tags/list"%r).get("tags") or [])-set(get("https://127.0.0.1:$(SERVER_PORT)/v2/%s/tags/list"%r).get("tags") or [])))) for r in leg];\
miss=[(r,t) for r,t in bad if t]; print("ok" if not miss else "missing");\
[print(r, t[:12]) for r,t in miss]'

# Drop sync config and stop the legacy distribution registry.
migrate-finish:
	docker rm -f $(ID)
	docker run $(DOCKER_RUN_OPTS) \
	    -d \
	    --name $(ID) \
	    --network host \
	    -v $(ZOT_DATA):/var/lib/registry \
	    -v $$(readlink -f zot):/etc/zot:ro \
	    -v $$(readlink -f certs):/certs:ro \
	    $(ZOT_IMAGE) serve /etc/zot/config.json
	docker rm -f $(ID)-legacy
	@echo "Zot is live on https://$(SERVER_HOST):$(SERVER_PORT)/ (UI + API)"

# Kept for compatibility; Zot UI replaces docker-registry-web.
run-web:
	@echo "Zot UI is at https://$(SERVER_HOST):$(WEB_PORT)/ — no separate web container."

start-web:
	@true

stop-web:
	@true

rm-web:
	@true

shell-web:
	docker exec -it $(ID) sh

deploy:
	rsync -amv Makefile certs zot $(SERVER_HOST):docker/registry
