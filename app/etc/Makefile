
create-bjnet:
	sudo docker network create \
	    --driver bridge \
	    --aux-address=192.168.201.181 \
	    --subnet=192.168.201.0/24 \
	    --gateway=192.168.201.120 \
	    --opt com.docker.network.bridge.name=docker1 \
	    bjnet

