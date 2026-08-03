#!/usr/bin/env bash
# Instance entrypoint: start services + create app DB (not part of b4f-rockynode image).
#
# Default configs:  /etc/rockynode/<name>.conf
# Instance override: /etc/rockynode.d/<name>.conf
#
# Env:
#   POSTGRES_DB / POSTGRES_USER / POSTGRES_PASSWORD
#   PGDATA  RABBITMQ_NODENAME  ROCKYNODE_SERVICES
set -euo pipefail

log() { printf 'rockynode-test: %s\n' "$*" >&2; }

export LANG="${LANG:-C.UTF-8}"
export LC_ALL="${LC_ALL:-C.UTF-8}"
export PGDATA="${PGDATA:-/var/lib/pgsql/data}"
export PATH="/usr/local/bin:${NVM_DIR:-/usr/local/nvm}/versions/node/v${NODE_VERSION:-22.22.2}/bin:${PATH:-}"
export RABBITMQ_NODENAME="${RABBITMQ_NODENAME:-rabbit@localhost}"

resolve_conf() {
  local name="$1"
  if [[ -f "/etc/rockynode.d/${name}" ]]; then
    echo "/etc/rockynode.d/${name}"
  else
    echo "/etc/rockynode/${name}"
  fi
}

want() {
  local svc="$1"
  local list="${ROCKYNODE_SERVICES:-postgres,valkey,nginx,rabbitmq,mosquitto}"
  [[ ",${list}," == *",${svc},"* ]]
}

mkdir -p /var/run/postgresql /var/lib/valkey /var/lib/rabbitmq /var/lib/mosquitto \
         /var/log/nginx /var/lib/nginx /run /etc/rockynode.d /etc/rabbitmq
chown -R postgres:postgres /var/run/postgresql 2>/dev/null || true
[[ -d "$PGDATA" ]] && chown -R postgres:postgres "$PGDATA" 2>/dev/null || true
chown -R rabbitmq:rabbitmq /var/lib/rabbitmq 2>/dev/null || true
chmod 755 /var/lib/valkey /var/lib/mosquitto 2>/dev/null || true

# ---------------------------------------------------------------------------
# PostgreSQL
# ---------------------------------------------------------------------------
if want postgres; then
  if [[ ! -f "$PGDATA/PG_VERSION" ]]; then
    log "initdb $PGDATA"
    mkdir -p "$PGDATA"
    chown -R postgres:postgres "$PGDATA"
    runuser -u postgres -- env LANG=C.UTF-8 LC_ALL=C.UTF-8 \
      /usr/bin/initdb -D "$PGDATA" --locale=C.UTF-8 --encoding=UTF8 \
      --auth-local=trust --auth-host=scram-sha-256
    cp "$(resolve_conf pg_hba.conf)" "$PGDATA/pg_hba.conf"
    chown postgres:postgres "$PGDATA/pg_hba.conf"
    chmod 600 "$PGDATA/pg_hba.conf"
    sed -ri "s/^#?(listen_addresses)[[:space:]]*=.*/\1 = '*'/" "$PGDATA/postgresql.conf"
    sed -ri "s/^#?(shared_buffers)[[:space:]]*=.*/\1 = 32MB/" "$PGDATA/postgresql.conf" || true
  fi

  log "start postgresql"
  runuser -u postgres -- /usr/bin/pg_ctl -D "$PGDATA" -l "$PGDATA/server.log" -w start

  DB="${POSTGRES_DB:-rockynode}"
  USER="${POSTGRES_USER:-rockynode}"
  PASS="${POSTGRES_PASSWORD:-rockynode}"

  if ! runuser -u postgres -- psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${USER}'" | grep -q 1; then
    runuser -u postgres -- psql -v ON_ERROR_STOP=1 -d postgres \
      -c "CREATE ROLE ${USER} LOGIN PASSWORD '${PASS}';"
  fi
  if ! runuser -u postgres -- psql -tAc "SELECT 1 FROM pg_database WHERE datname='${DB}'" | grep -q 1; then
    runuser -u postgres -- createdb -O "$USER" "$DB"
  fi
  runuser -u postgres -- psql -v ON_ERROR_STOP=1 -d "$DB" \
    -c 'CREATE EXTENSION IF NOT EXISTS postgis;'
fi

# ---------------------------------------------------------------------------
# Valkey
# ---------------------------------------------------------------------------
if want valkey; then
  log "start valkey ($(resolve_conf valkey.conf))"
  env LANG=C.UTF-8 LC_ALL=C.UTF-8 valkey-server "$(resolve_conf valkey.conf)" &
fi

# ---------------------------------------------------------------------------
# nginx
# ---------------------------------------------------------------------------
if want nginx; then
  log "start nginx"
  nginx -g 'daemon off;' &
fi

# ---------------------------------------------------------------------------
# RabbitMQ
# ---------------------------------------------------------------------------
if want rabbitmq; then
  log "start rabbitmq ($(resolve_conf rabbitmq.conf))"
  grep -qE '[[:space:]]localhost([[:space:]]|$)' /etc/hosts 2>/dev/null \
    || echo '127.0.0.1 localhost' >>/etc/hosts
  export RABBITMQ_CONFIG_FILE
  RABBITMQ_CONFIG_FILE="$(resolve_conf rabbitmq.conf)"
  RABBITMQ_CONFIG_FILE="${RABBITMQ_CONFIG_FILE%.conf}"
  export RABBITMQ_CONFIG_FILE
  rabbitmq-plugins enable --offline rabbitmq_management >/dev/null 2>&1 || true
  rabbitmq-server &
  for i in $(seq 1 60); do
    if rabbitmqctl -n "$RABBITMQ_NODENAME" status >/dev/null 2>&1; then
      log "rabbitmq ready (${i}s)"
      break
    fi
    sleep 1
  done
fi

# ---------------------------------------------------------------------------
# Mosquitto
# ---------------------------------------------------------------------------
if want mosquitto; then
  log "start mosquitto ($(resolve_conf mosquitto.conf))"
  mosquitto -c "$(resolve_conf mosquitto.conf)" &
fi

log "ready — postgres:5432 redis:6379 http:80 amqp:5672 mqtt:1883"
trap 'log stopping; want postgres && runuser -u postgres -- /usr/bin/pg_ctl -D "$PGDATA" -m fast -w stop 2>/dev/null || true; kill 0 2>/dev/null || true; exit 0' TERM INT
while true; do sleep 3600; done
