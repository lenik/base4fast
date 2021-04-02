include docker/container.mk

ID = registry
GUEST_SHELL = /bin/ash -l

SERVER_HOST = docker.bodz.net
SERVER_PORT = 5000

-run-docker:
	#docker pull $(REPO)/registry
	docker run $(DOCKER_RUN_OPTS) \
	    -d \
	    --name $(ID) \
	    -p $(SERVER_PORT):443 \
	    -v $$(readlink -f data):/var/lib/registry \
	    -v $$(readlink -f certs):/certs \
	    -e REGISTRY_HTTP_ADDR=0.0.0.0:443 \
	    -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
	    -e REGISTRY_HTTP_TLS_KEY=/certs/domain.pem \
	    registry:2

run-web:
	docker pull $(REPO)/docker-registry-web
	docker run \
            -d \
	    --name $(ID)-web \
	    --link $(ID) \
            -p 8562:8080 \
	    -e REGISTRY_URL=https://$(ID):443/v2/ \
	    -e REGISTRY_NAME=$(SERVER_HOST):$(SERVER_PORT) \
	    -e REGISTRY_TRUST_ANY_SSL=true \
	    -e REGISTRY_BASIC_AUTH="YWRtaW46Y2hhbmdlbWU=" \
	    $(REPO)/docker-registry-web

start-web:
	docker start $(ID)-web

stop-web:
	docker stop $(ID)-web

rm-web: stop-web
	docker rm $(ID)-web

shell-web:
	docker exec -it $(ID)-web /bin/bash

deploy:
	rsync -amv Makefile certs $(SERVER_HOST):docker/registry

