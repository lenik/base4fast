include docker/container.mk

ID = leijee
VERSION = bullseye

FROM = leideb:${VERSION}
LABEL = Lenik's Java Web Server

DOCKER_BUILD_OPTS = \
    --build-arg "FROM=${FROM}" \
    --build-arg "LABEL=${LABEL}" \
    --squash

-run-docker:
	echoli DUMP: $(DOCKER_BUILD_OPTS)
	#docker pull $(REPO)/$(ID)
	docker run $(DOCKER_RUN_OPTS) \
	    -it \
	    --name $(ID) \
            $(ID):$(VERSION)

clean:
	rm -fr ./jdk-1.8.0-64

