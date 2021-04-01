include docker/container.mk

ID = leijee
VERSION = buster

DO_PREBUILD = 
DO_POSTBUILD = 

-run-docker:
	#docker pull $(REPO)/$(ID)
	docker run $(DOCKER_RUN_OPTS) \
	    -it \
	    --name $(ID) \
            $(ID):$(VERSION)

clean:
	rm -fr ./jdk-1.8.0-64

