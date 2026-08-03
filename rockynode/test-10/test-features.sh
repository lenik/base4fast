#!/usr/bin/env bash
# Smoke-test features of the rockynode-test-10 instance (from the host).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

HOST="${HOST:-127.0.0.1}"
PGPORT="${PGPORT:-15432}"
REDIS_PORT="${REDIS_PORT:-16379}"
HTTP_PORT="${HTTP_PORT:-18080}"
AMQP_PORT="${AMQP_PORT:-15671}"
MQ_UI_PORT="${MQ_UI_PORT:-15672}"
MQTT_PORT="${MQTT_PORT:-11883}"
CONTAINER="${CONTAINER:-rockynode-test-10}"

PASS=0
FAIL=0

ok()   { printf '  OK  %s\n' "$*"; PASS=$((PASS + 1)); }
bad()  { printf '  FAIL %s\n' "$*"; FAIL=$((FAIL + 1)); }
info() { printf '== %s\n' "$*"; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }
}

wait_tcp() {
  local host="$1" port="$2" name="$3" n="${4:-30}"
  local i
  for i in $(seq 1 "$n"); do
    if (echo >/dev/tcp/"$host"/"$port") >/dev/null 2>&1; then
      return 0
    fi
    # fallback without bash /dev/tcp
    if command -v nc >/dev/null 2>&1 && nc -z "$host" "$port" 2>/dev/null; then
      return 0
    fi
    sleep 1
  done
  bad "$name not listening on ${host}:${port}"
  return 1
}

info "container running"
if docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null | grep -q true; then
  ok "container $CONTAINER is running"
else
  bad "container $CONTAINER is not running"
  echo "run: make -C $ROOT up" >&2
  exit 1
fi

info "ports"
wait_tcp "$HOST" "$PGPORT" "postgresql" 45 || true
wait_tcp "$HOST" "$REDIS_PORT" "valkey/redis" 30 || true
wait_tcp "$HOST" "$HTTP_PORT" "nginx" 20 || true
wait_tcp "$HOST" "$AMQP_PORT" "rabbitmq-amqp" 60 || true
wait_tcp "$HOST" "$MQTT_PORT" "mosquitto" 20 || true

info "postgresql + postgis"
if docker exec "$CONTAINER" runuser -u postgres -- \
     psql -d rockynode -tAc "SELECT PostGIS_Version();" 2>/dev/null | grep -q .; then
  ok "PostGIS extension responds"
else
  bad "PostGIS query failed"
fi
if docker exec "$CONTAINER" runuser -u postgres -- \
     psql -d rockynode -tAc "SELECT 1;" 2>/dev/null | grep -q 1; then
  ok "psql SELECT 1"
else
  bad "psql SELECT 1"
fi
# password auth from host if psql client exists
if command -v psql >/dev/null 2>&1; then
  if PGPASSWORD=rockynode psql -h "$HOST" -p "$PGPORT" -U rockynode -d rockynode -tAc "SELECT 1" 2>/dev/null | grep -q 1; then
    ok "host psql scram auth (rockynode/rockynode@${HOST}:${PGPORT})"
  else
    bad "host psql scram auth"
  fi
else
  info "(skip host psql — client not installed)"
fi

info "valkey / redis"
if docker exec "$CONTAINER" redis-cli -h 127.0.0.1 ping 2>/dev/null | grep -qi pong; then
  ok "redis-cli PING → PONG"
else
  bad "redis-cli PING"
fi
docker exec "$CONTAINER" redis-cli SET rockynode:test "ok-$(date +%s)" >/dev/null 2>&1 || true
if docker exec "$CONTAINER" redis-cli GET rockynode:test 2>/dev/null | grep -q '^ok-'; then
  ok "redis SET/GET"
else
  bad "redis SET/GET"
fi

info "nginx"
if curl -fsS "http://${HOST}:${HTTP_PORT}/" 2>/dev/null | grep -qE 'rockynode|b4f-rockynode'; then
  ok "HTTP ${HTTP_PORT} serves page"
else
  bad "HTTP ${HTTP_PORT}"
fi

info "node / nrm / pnpm"
NODE_VER="$(docker exec "$CONTAINER" node -v 2>/dev/null || true)"
NRM_OUT="$(docker exec "$CONTAINER" nrm current 2>/dev/null || true)"
PNPM_VER="$(docker exec "$CONTAINER" pnpm -v 2>/dev/null || true)"
if [[ "$NODE_VER" == v22* ]] && [[ "$NRM_OUT" == *taobao* ]] && [[ -n "$PNPM_VER" ]]; then
  ok "node $NODE_VER / nrm taobao / pnpm $PNPM_VER"
else
  bad "node/nrm/pnpm (node='$NODE_VER' nrm='$NRM_OUT' pnpm='$PNPM_VER')"
fi

info "rabbitmq"
export RABBITMQ_NODENAME=rabbit@localhost
if docker exec -e RABBITMQ_NODENAME=rabbit@localhost "$CONTAINER" \
     rabbitmqctl -n rabbit@localhost status >/dev/null 2>&1; then
  ok "rabbitmqctl status"
else
  # give broker a bit more time
  sleep 5
  if docker exec -e RABBITMQ_NODENAME=rabbit@localhost "$CONTAINER" \
       rabbitmqctl -n rabbit@localhost status >/dev/null 2>&1; then
    ok "rabbitmqctl status"
  else
    bad "rabbitmqctl status"
  fi
fi
if curl -fsS -u guest:guest "http://${HOST}:${MQ_UI_PORT}/api/overview" 2>/dev/null | grep -q '"rabbitmq_version"'; then
  ok "RabbitMQ management API :${MQ_UI_PORT} (guest/guest)"
else
  sleep 3
  if curl -fsS -u guest:guest "http://${HOST}:${MQ_UI_PORT}/api/overview" 2>/dev/null | grep -q '"rabbitmq_version"'; then
    ok "RabbitMQ management API :${MQ_UI_PORT} (guest/guest)"
  else
    bad "RabbitMQ management API :${MQ_UI_PORT}"
  fi
fi

info "mosquitto"
if docker exec "$CONTAINER" bash -lc 'command -v mosquitto_pub >/dev/null && mosquitto_pub -h 127.0.0.1 -t rockynode/test -m ping -q 0' 2>/dev/null; then
  ok "mosquitto_pub to localhost"
elif docker exec "$CONTAINER" bash -lc 'timeout 1 bash -c "echo >/dev/tcp/127.0.0.1/1883"' 2>/dev/null; then
  ok "mqtt port open (no mosquitto_pub client package)"
else
  # host-side TCP already checked; soft-fail if pub client missing
  if (echo >/dev/tcp/"$HOST"/"$MQTT_PORT") >/dev/null 2>&1 || nc -z "$HOST" "$MQTT_PORT" 2>/dev/null; then
    ok "mqtt TCP ${HOST}:${MQTT_PORT}"
  else
    bad "mosquitto"
  fi
fi

info "tools present"
for c in curl wget aria2c vim nginx redis-server psql; do
  if docker exec "$CONTAINER" bash -lc "command -v $c" >/dev/null 2>&1; then
    ok "cmd $c"
  else
    bad "cmd $c"
  fi
done

echo
echo "passed=$PASS failed=$FAIL"
[[ "$FAIL" -eq 0 ]]
