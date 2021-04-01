include docker/container.mk

ID = cdh5
IMAGE = quickstart

-run-docker:
	docker run $(DOCKER_RUN_OPTS) \
	    -it -P \
	    --privileged=true \
	    --name $(ID) \
	    --hostname=$(ID) \
	    $(REPO)/$(IMAGE) \
	    /usr/bin/docker-quickstart

