include docker/container.mk

ID = centos-cn
VERSION = latest

-run-docker:
	#docker pull $(REPO)/centos7-cn
	docker run $(DOCKER_RUN_OPTS) \
	    -it \
	    --name $(ID) \
	    -v $$HOME:/home \
	    $(IMAGE):$(VERSION)

