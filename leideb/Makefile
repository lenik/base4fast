include docker/container.mk

ID = leideb
VERSION = bullseye

DOCKER_BUILD_OPTS=--squash
#DO_PREBUILD = 
#DO_POSTBUILD = 

#DOCKER_RUN_VOLS=

-run-docker:
	#docker pull $(REPO)/$(ID)
	docker run $(DOCKER_RUN_OPTS) \
	    -it \
	    --name $(ID) \
	    $(ID):$(VERSION)

clean:
	rm -fr ./jdk-1.8.0-64

