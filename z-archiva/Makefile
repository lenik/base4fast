include docker/container.mk

ID = z-archiva

-run-docker:
	docker run -it $(DOCKER_RUN_OPTS) \
	    --restart unless-stopped \
	    --name $(ID) \
	    -p 8146:8080 \
	    -v /repo/m2:/repo/m2 \
	    -v /repo/m2/archiva:/var/archiva \
	    $(ID)

rr: rm run

DBG:
	    --entrypoint /bin/bash \
