IMAGE ?= b4f-rockynode:10
COMPOSE ?= docker compose

.PHONY: up down restart logs shell ps test wait clean status

up:
	@test -n "$$(docker images -q $(IMAGE))" || { \
	  echo "missing image $(IMAGE); build with: make -C ../10 bake" >&2; exit 1; }
	mkdir -p data/pgsql data/valkey data/rabbitmq data/mosquitto overrides
	$(COMPOSE) up -d
	@$(MAKE) --no-print-directory wait

down:
	$(COMPOSE) down

restart: down up

logs:
	$(COMPOSE) logs -f --tail=100

shell:
	$(COMPOSE) exec rockynode bash -l

ps status:
	$(COMPOSE) ps

wait:
	@echo "waiting for services..."
	@for i in $$(seq 1 90); do \
	  pg_ok=0; rd_ok=0; \
	  docker exec rockynode-test-10 runuser -u postgres -- psql -d rockynode -tAc 'SELECT 1' >/dev/null 2>&1 && pg_ok=1; \
	  docker exec rockynode-test-10 redis-cli ping 2>/dev/null | grep -qi pong && rd_ok=1; \
	  if [ "$$pg_ok" = 1 ] && [ "$$rd_ok" = 1 ]; then \
	    echo "ready ($${i}s)"; exit 0; \
	  fi; \
	  sleep 1; \
	done; \
	echo "timeout — try: make logs" >&2; \
	$(COMPOSE) logs --tail=40 >&2 || true; \
	exit 1

test: wait
	./test-features.sh

clean: down
	docker run --rm --entrypoint bash \
	  -v "$(CURDIR)/data:/data" $(IMAGE) \
	  -lc 'rm -rf /data/pgsql /data/valkey /data/rabbitmq /data/mosquitto'
	mkdir -p data/pgsql data/valkey data/rabbitmq data/mosquitto overrides
