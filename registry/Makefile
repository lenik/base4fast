include docker/container.mk

ID = registry
GUEST_SHELL = /bin/ash -l

-run-docker:
	#docker pull $(REPO)/registry
	docker run -d $(DOCKER_RUN_OPTS) \
	    --name $(ID) \
	    -p 5000:5000 \
	    -v $$(readlink -f data):/var/lib/registry \
	    registry
#	    -v $$(readlink -f certs):/certs \
#	    -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
#	    -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \

run-web:
	docker pull $(REPO)/docker-registry-web
	docker run -d -p 8562:8080 \
	    --name $(ID)-web \
	    --link $(ID) \
	    -e REGISTRY_URL=http://$(ID):5000/v2 \
	    -e REGISTRY_NAME=localhost:5000 \
	    $(REPO)/docker-registry-web
	    #-e REGISTRY_TRUSE_ANY_SSL=true \
	    #-e REGISTRY_BASIC_AUTH="YWRtaW46Y2hhbmdlbWU=" \

start-web:
	docker start $(ID)-web

stop-web:
	docker stop $(ID)-web

rm-web: stop-web
	docker rm $(ID)-web

shell-web:
	docker exec -it $(ID)-web /bin/bash

