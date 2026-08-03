ARG VERSION=1.0-snapshot
# Parent base may be registry-qualified; override with --build-arg BASE_IMAGE=...
ARG BASE_IMAGE=183.131.83.99:1244/b4f-rocky:10
FROM ${BASE_IMAGE}

ARG VERSION
ARG NODE_VERSION=22.22.2
ARG NVM_VERSION=0.40.3

LABEL maintainer="Lenik <lenik@bodz.net>"
LABEL description="Rocky Linux 10 node stack (PostgreSQL/PostGIS, Node, nginx, redis/valkey, rabbitmq, mosquitto)"
LABEL version=${VERSION}

ENV PATH="/usr/local/bin:${PATH}"
ENV NVM_DIR=/usr/local/nvm
ENV NODE_VERSION=${NODE_VERSION}
ENV NPM_CONFIG_REGISTRY=https://registry.npmmirror.com

# Neutral defaults for the shared base (apps like mpss set their own locale/TZ).
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    TZ=Asia/Shanghai

# ---------------------------------------------------------------------------
# 1. EPEL + packages (bwsel+install in one layer; fall back if mirror 404s)
# ---------------------------------------------------------------------------
RUN --mount=type=cache,id=rockynode-10-dnf-v3,target=/var/cache/dnf,sharing=locked \
    set -e; \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime; \
    echo $TZ > /etc/timezone; \
    ensure_repos() { \
      yum-via-lrm.sh rocky:10 --everything --epel; \
      dnf -y clean metadata >/dev/null 2>&1 || true; \
      if dnf -q repoquery --repo=lrm-baseos wget >/dev/null 2>&1; then return 0; fi; \
      echo "lrm: selected mirror unhealthy; trying fallbacks" >&2; \
      for m in huawei tuna rocky 163; do \
        echo "lrm: use $m" >&2; \
        lrm --distro rocky:10 use --everything --epel "$m" || continue; \
        dnf -y clean metadata >/dev/null 2>&1 || true; \
        if dnf -q repoquery --repo=lrm-baseos wget >/dev/null 2>&1; then return 0; fi; \
      done; \
      return 1; \
    }; \
    ensure_repos; \
    dnf -y --setopt=install_weak_deps=False --setopt=skip_if_unavailable=False install \
        curl wget aria2 vim-enhanced \
        iproute net-tools \
        findutils tar xz zstd gzip bzip2 unzip \
        nginx \
        valkey \
        mosquitto \
        postgresql postgresql-server postgresql-contrib postgis \
        glibc-langpack-en glibc-langpack-de glibc-langpack-zh \
        glibc-langpack-ja glibc-langpack-ko glibc-langpack-ru \
        glibc-langpack-th glibc-langpack-vi glibc-langpack-it \
        glibc-langpack-ar glibc-langpack-he glibc-langpack-eo \
        logrotate \
        which \
    && dnf -y clean all \
    && ln -sf /usr/bin/valkey-server /usr/local/bin/redis-server \
    && ln -sf /usr/bin/valkey-cli /usr/local/bin/redis-cli \
    && ln -sf /usr/bin/valkey-benchmark /usr/local/bin/redis-benchmark \
    && (command -v valkey-check-rdb >/dev/null && ln -sf /usr/bin/valkey-check-rdb /usr/local/bin/redis-check-rdb || true) \
    && (command -v valkey-check-aof >/dev/null && ln -sf /usr/bin/valkey-check-aof /usr/local/bin/redis-check-aof || true)

# ---------------------------------------------------------------------------
# 2. Erlang + RabbitMQ from host-downloaded RPMs
# ---------------------------------------------------------------------------
COPY vendor/rpms/ /tmp/rpms/
RUN --mount=type=cache,id=rockynode-10-dnf-v3,target=/var/cache/dnf,sharing=locked \
    dnf -y install /tmp/rpms/*.rpm \
    && rm -rf /tmp/rpms \
    && dnf -y clean all

# ---------------------------------------------------------------------------
# 3. Default configs only (instances override via /etc/rockynode.d/)
#     No service start / no DB bootstrap in this image.
# ---------------------------------------------------------------------------
COPY etc/pg_hba.conf etc/valkey.conf etc/mosquitto.conf etc/rabbitmq.conf /etc/rockynode/
COPY www/ /usr/share/nginx/html/
RUN mkdir -p /etc/rockynode.d /var/lib/valkey /var/lib/mosquitto /var/lib/rabbitmq \
             /var/lib/pgsql /var/run/postgresql \
    && chown -R postgres:postgres /var/lib/pgsql /var/run/postgresql \
    && rabbitmq-plugins enable --offline rabbitmq_management >/dev/null 2>&1 || true

EXPOSE 5432 6379 80 443 5672 15672 1883

# ---------------------------------------------------------------------------
# 4. Default app user BEFORE npm/nvm/pnpm data (owns store + /opt/minimal)
# ---------------------------------------------------------------------------
RUN groupadd -g 1000 node 2>/dev/null || groupadd node \
    && useradd -u 1000 -g node -m -d /home/node -s /bin/bash node \
    && mkdir -p /home/node /var/cache/pnpm /opt/minimal \
    && chown -R node:node /home/node /var/cache/pnpm /opt/minimal \
    && echo "node user ready: $(id node)"

# ---------------------------------------------------------------------------
# 5. nvm + Node (host-downloaded) + nrm/pnpm from vendored global prefix
# ---------------------------------------------------------------------------
COPY vendor/nvm/nvm-${NVM_VERSION}.tar.gz /tmp/nvm.tar.gz
COPY vendor/node/node-v${NODE_VERSION}-linux-x64.tar.xz /tmp/node.tar.xz
COPY vendor/npm-global/ /tmp/npm-global/

RUN mkdir -p "${NVM_DIR}" \
    && tar -xzf /tmp/nvm.tar.gz -C "${NVM_DIR}" --strip-components=1 \
    && mkdir -p "${NVM_DIR}/versions/node" \
    && tar -xJf /tmp/node.tar.xz -C "${NVM_DIR}/versions/node" \
    && mv "${NVM_DIR}/versions/node/node-v${NODE_VERSION}-linux-x64" \
          "${NVM_DIR}/versions/node/v${NODE_VERSION}" \
    && mkdir -p "${NVM_DIR}/alias" \
    && printf '%s\n' "${NODE_VERSION}" >"${NVM_DIR}/alias/default" \
    && printf '%s\n' "${NODE_VERSION}" >"${NVM_DIR}/alias/stable" \
    && NODE_HOME="${NVM_DIR}/versions/node/v${NODE_VERSION}" \
    && cp -a /tmp/npm-global/lib/node_modules/. "${NODE_HOME}/lib/node_modules/" \
    && if [ -d /tmp/npm-global/bin ]; then cp -a /tmp/npm-global/bin/. "${NODE_HOME}/bin/"; fi \
    && ln -sfn ../lib/node_modules/nrm/dist/index.js "${NODE_HOME}/bin/nrm" \
    && ln -sfn ../lib/node_modules/pnpm/bin/pnpm.cjs "${NODE_HOME}/bin/pnpm" \
    && ln -sfn ../lib/node_modules/pnpm/bin/pnpx.cjs "${NODE_HOME}/bin/pnpx" \
    && chmod +x "${NODE_HOME}/lib/node_modules/nrm/dist/index.js" \
                "${NODE_HOME}/lib/node_modules/pnpm/bin/"*.cjs \
    && rm -rf /tmp/nvm.tar.gz /tmp/node.tar.xz /tmp/npm-global \
    && ln -sfn "${NODE_HOME}/bin/node" /usr/local/bin/node \
    && ln -sfn "${NODE_HOME}/bin/npm" /usr/local/bin/npm \
    && ln -sfn "${NODE_HOME}/bin/npx" /usr/local/bin/npx \
    && ln -sfn "${NODE_HOME}/bin/nrm" /usr/local/bin/nrm \
    && ln -sfn "${NODE_HOME}/bin/pnpm" /usr/local/bin/pnpm \
    && ln -sfn "${NODE_HOME}/bin/pnpx" /usr/local/bin/pnpx \
    && chown -R node:node "${NVM_DIR}" \
    && export PATH="${NODE_HOME}/bin:${PATH}" \
    && runuser -u node -- env HOME=/home/node PATH="${NODE_HOME}/bin:${PATH}" nrm use taobao \
    && node -v && npm -v && nrm current && pnpm -v

ENV PATH="${NVM_DIR}/versions/node/v${NODE_VERSION}/bin:${PATH}"

# ---------------------------------------------------------------------------
# 6. Shared pnpm store + minimal seed metadata (owned by node)
# ---------------------------------------------------------------------------
# Layout: vendor/pnpm-store/v3/{files,index.db} → PNPM_STORE_DIR/v3 (pnpm appends /v3)
COPY --chown=node:node vendor/pnpm-store/ /var/cache/pnpm/store/
COPY --chown=node:node vendor/minimal/package.json \
                       vendor/minimal/pnpm-lock.yaml \
                       vendor/minimal/README.md \
                       vendor/minimal/MANIFEST.txt \
                       /opt/minimal/

ENV PNPM_STORE_DIR=/var/cache/pnpm/store \
    npm_config_store_dir=/var/cache/pnpm/store

# System + node-user npmrc (pnpm prefers ~/.npmrc).
# Do NOT chown -R the store here — COPY --chown already owns it; recursive
# chown on ~10k CAFS files is minutes of build time for no benefit.
RUN printf '%s\n' \
      'store-dir=/var/cache/pnpm/store' \
      'registry=https://registry.npmmirror.com' \
      | tee /etc/npmrc /home/node/.npmrc >/dev/null \
    && chown node:node /home/node/.npmrc \
    && test -d /var/cache/pnpm/store/v3 \
    && printf '%s\n' \
         'export PNPM_STORE_DIR=/var/cache/pnpm/store' \
         'export npm_config_store_dir=/var/cache/pnpm/store' \
         > /etc/profile.d/pnpm-store.sh \
    && chmod 644 /etc/profile.d/pnpm-store.sh /etc/npmrc \
    && echo "pnpm store ready: $(du -sh /var/cache/pnpm/store | awk '{print $1}') owned by $(stat -c '%U:%G' /var/cache/pnpm/store)" \
    ; \
    printf '%s\n' \
      "export NVM_DIR=\"${NVM_DIR}\"" \
      '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"' \
      > /etc/profile.d/nvm.sh \
    && chmod 644 /etc/profile.d/nvm.sh \
    && if [ -f /etc/bashrc.base4fast ]; then \
         printf '\n%s\n' '[ -f /etc/profile.d/nvm.sh ] && . /etc/profile.d/nvm.sh' \
           >> /etc/bashrc.base4fast; \
       fi

# Upper images that need root (e.g. mpss entrypoint for postgres/nginx) must USER root.
USER node
WORKDIR /home/node

ENTRYPOINT ["/bin/bash", "-i"]
