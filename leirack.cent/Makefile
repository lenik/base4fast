include docker/container.mk

ID = leirack.cent
VERSION = latest

-run-docker:
	#docker pull $(REPO)/$(ID)
	docker run $(DOCKER_RUN_OPTS) \
	    -it \
	    --name $(ID) \
	    -v $$HOME:/home \
	    $(ID)

