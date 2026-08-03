#!/usr/bin/env bash
# Download artifacts on the host for COPY into the image.
# Direct downloads from inside the container often fail in restricted networks.
#
# Two download modes:
#   download_cn   direct (no proxy) — China mirrors / ghproxy
#   download_any  uses http_proxy / https_proxy / ALL_PROXY etc.
#
# Env:
#   http_proxy / https_proxy / HTTP_PROXY / HTTPS_PROXY / ALL_PROXY  for download_any
#   NODE_VERSION   default 22.22.2
#   NVM_VERSION    default 0.40.3
#   ERLANG_RPM_VER default 27.3.4.15-1.el10
#   RABBITMQ_VER   default 4.3.4
#   FORCE=1        re-download even if files exist

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
VENDOR="${ROOT}/vendor"
NODE_VERSION="${NODE_VERSION:-22.22.2}"
NVM_VERSION="${NVM_VERSION:-0.40.3}"
ERLANG_RPM_VER="${ERLANG_RPM_VER:-27.3.4.15-1.el10}"
RABBITMQ_VER="${RABBITMQ_VER:-4.3.4}"

mkdir -p "${VENDOR}/rpms" "${VENDOR}/node" "${VENDOR}/nvm"

log() { printf 'prebuild: %s\n' "$*" >&2; }

# Prefer system curl (avoid interactive shell wrappers).
CURL_BIN=/usr/bin/curl
CURL_BASE=(-fL --retry 3 --retry-delay 2 --connect-timeout 20)
HAS_ARIA=0
if command -v aria2c >/dev/null 2>&1; then
  HAS_ARIA=1
fi

# Snapshot proxy from the environment for download_any.
PROXY_HTTP="${http_proxy:-${HTTP_PROXY:-}}"
PROXY_HTTPS="${https_proxy:-${HTTPS_PROXY:-${PROXY_HTTP}}}"
PROXY_ALL="${all_proxy:-${ALL_PROXY:-}}"
PROXY_NO="${no_proxy:-${NO_PROXY:-}}"

_fetch() {
  # _fetch MODE URL DEST
  # MODE: cn | any
  local mode="$1" url="$2" dest="$3"
  local tmp="${dest}.part"
  rm -f "$tmp" "${tmp}.aria2"

  log "[$mode] GET $url -> $(basename "$dest")"

  if [[ "$mode" == cn ]]; then
    # Direct path: clear proxy only inside the subshell (no parent side-effects).
    (
      unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY \
            all_proxy ALL_PROXY no_proxy NO_PROXY
      if [[ "$HAS_ARIA" -eq 1 ]]; then
        aria2c -c -x 8 -s 8 --connect-timeout=20 --max-tries=3 \
          --no-proxy='*' \
          -o "$(basename "$tmp")" -d "$(dirname "$tmp")" "$url"
      else
        "$CURL_BIN" "${CURL_BASE[@]}" --noproxy '*' -o "$tmp" "$url"
      fi
    )
    return $?
  fi

  # any: honor snapshot proxy settings (scoped to this command via env=).
  local curl_proxy=() aria_proxy=()
  if [[ -n "$PROXY_HTTPS" ]]; then
    curl_proxy+=(--proxy "$PROXY_HTTPS")
    aria_proxy+=(--all-proxy="$PROXY_HTTPS")
  elif [[ -n "$PROXY_HTTP" ]]; then
    curl_proxy+=(--proxy "$PROXY_HTTP")
    aria_proxy+=(--all-proxy="$PROXY_HTTP")
  elif [[ -n "$PROXY_ALL" ]]; then
    curl_proxy+=(--proxy "$PROXY_ALL")
    aria_proxy+=(--all-proxy="$PROXY_ALL")
  fi

  (
    export http_proxy="$PROXY_HTTP" https_proxy="$PROXY_HTTPS" \
           HTTP_PROXY="$PROXY_HTTP" HTTPS_PROXY="$PROXY_HTTPS" \
           all_proxy="$PROXY_ALL" ALL_PROXY="$PROXY_ALL" \
           no_proxy="$PROXY_NO" NO_PROXY="$PROXY_NO"
    if [[ "$HAS_ARIA" -eq 1 ]]; then
      aria2c -c -x 8 -s 8 --connect-timeout=20 --max-tries=3 \
        "${aria_proxy[@]}" \
        -o "$(basename "$tmp")" -d "$(dirname "$tmp")" "$url"
    else
      "$CURL_BIN" "${CURL_BASE[@]}" "${curl_proxy[@]}" -o "$tmp" "$url"
    fi
  )
  return $?
}

_download() {
  # _download MODE DEST URL [URL...]
  local mode="$1" dest="$2"
  shift 2

  if [[ -f "$dest" && "${FORCE:-0}" != 1 ]]; then
    log "skip (exists): $(basename "$dest")"
    return 0
  fi

  local url tmp="${dest}.part" ok=0
  for url in "$@"; do
    [[ -z "$url" ]] && continue
    if _fetch "$mode" "$url" "$dest"; then
      ok=1
      break
    fi
    log "[$mode] failed: $url"
    rm -f "$tmp" "${tmp}.aria2"
  done

  [[ "$ok" -eq 1 ]] || return 1
  mv -f "$tmp" "$dest"
  log "ok: $(basename "$dest") ($(wc -c <"$dest") bytes)"
}

# Direct download (no proxy) — CN mirrors / ghproxy.
download_cn() {
  local dest="$1"
  shift
  _download cn "$dest" "$@"
}

# Download using proxy settings from the environment.
download_any() {
  local dest="$1"
  shift
  _download any "$dest" "$@"
}

# Try CN direct first, then proxy-aware international mirrors.
download() {
  local dest="$1"
  shift
  local -a cn_urls=() any_urls=()
  local u
  for u in "$@"; do
    case "$u" in
    *huaweicloud.com*|*npmmirror.com*|*cdn.npmmirror.com*|*ghproxy.net*|*mirror.aliyun.com*|*mirrors.tuna.tsinghua.edu.cn*|*mirrors.ustc.edu.cn*|*mirrors.cloud.tencent.com*)
      cn_urls+=("$u")
      ;;
    *)
      any_urls+=("$u")
      ;;
    esac
  done

  if ((${#cn_urls[@]})) && download_cn "$dest" "${cn_urls[@]}"; then
    return 0
  fi
  if ((${#any_urls[@]})) && download_any "$dest" "${any_urls[@]}"; then
    return 0
  fi
  # Last resort: try the other mode on remaining URLs.
  if ((${#any_urls[@]})) && download_cn "$dest" "${any_urls[@]}"; then
    return 0
  fi
  if ((${#cn_urls[@]})) && download_any "$dest" "${cn_urls[@]}"; then
    return 0
  fi
  log "error: could not download $(basename "$dest")"
  exit 1
}

# ---------------------------------------------------------------------------
# Node.js binary (nvm will use this offline)
# ---------------------------------------------------------------------------
NODE_TAR="node-v${NODE_VERSION}-linux-x64.tar.xz"
NODE_DEST="${VENDOR}/node/${NODE_TAR}"
download "$NODE_DEST" \
  "https://mirrors.huaweicloud.com/nodejs/v${NODE_VERSION}/${NODE_TAR}" \
  "https://npmmirror.com/mirrors/node/v${NODE_VERSION}/${NODE_TAR}" \
  "https://nodejs.org/dist/v${NODE_VERSION}/${NODE_TAR}"

# ---------------------------------------------------------------------------
# nvm sources
# ---------------------------------------------------------------------------
NVM_TAR="nvm-${NVM_VERSION}.tar.gz"
NVM_DEST="${VENDOR}/nvm/${NVM_TAR}"
download "$NVM_DEST" \
  "https://ghproxy.net/https://github.com/nvm-sh/nvm/archive/refs/tags/v${NVM_VERSION}.tar.gz" \
  "https://github.com/nvm-sh/nvm/archive/refs/tags/v${NVM_VERSION}.tar.gz"

# ---------------------------------------------------------------------------
# Erlang (el10) + RabbitMQ server RPMs
# ---------------------------------------------------------------------------
ERLANG_RPM="erlang-${ERLANG_RPM_VER}.x86_64.rpm"
ERLANG_TAG="v${ERLANG_RPM_VER%%-*}"
ERLANG_DEST="${VENDOR}/rpms/${ERLANG_RPM}"
download "$ERLANG_DEST" \
  "https://ghproxy.net/https://github.com/rabbitmq/erlang-rpm/releases/download/${ERLANG_TAG}/${ERLANG_RPM}" \
  "https://github.com/rabbitmq/erlang-rpm/releases/download/${ERLANG_TAG}/${ERLANG_RPM}"

RABBIT_RPM="rabbitmq-server-${RABBITMQ_VER}-1.el8.noarch.rpm"
RABBIT_DEST="${VENDOR}/rpms/${RABBIT_RPM}"
download "$RABBIT_DEST" \
  "https://ghproxy.net/https://github.com/rabbitmq/rabbitmq-server/releases/download/v${RABBITMQ_VER}/${RABBIT_RPM}" \
  "https://github.com/rabbitmq/rabbitmq-server/releases/download/v${RABBITMQ_VER}/${RABBIT_RPM}" \
  "https://yum1.rabbitmq.com/rabbitmq/el/9/noarch/${RABBIT_RPM}"

# ---------------------------------------------------------------------------
# Vendor nrm+pnpm into a small prefix (avoid shipping host npm/pnpm caches).
# Prefer host global modules; fall back to npm --prefer-offline.
# ---------------------------------------------------------------------------
vendor_npm_global() {
  local npm_bin="" cache="${NPM_CACHE:-${HOME}/.npm}"
  NPM_GLOBAL="${VENDOR}/npm-global"

  if [[ -d "${NPM_GLOBAL}/lib/node_modules/nrm" && -d "${NPM_GLOBAL}/lib/node_modules/pnpm" && "${FORCE:-0}" != 1 ]]; then
    log "skip (exists): npm-global (nrm+pnpm)"
    return 0
  fi

  if [[ -d /usr/lib/node_modules/nrm && -d /usr/lib/node_modules/pnpm ]]; then
    log "copy host /usr/lib/node_modules/{nrm,pnpm} -> vendor/npm-global"
    rm -rf "${NPM_GLOBAL}"
    mkdir -p "${NPM_GLOBAL}/lib/node_modules" "${NPM_GLOBAL}/bin"
    cp -a /usr/lib/node_modules/nrm "${NPM_GLOBAL}/lib/node_modules/"
    cp -a /usr/lib/node_modules/pnpm "${NPM_GLOBAL}/lib/node_modules/"
    ln -sfn ../lib/node_modules/nrm/dist/index.js "${NPM_GLOBAL}/bin/nrm"
    ln -sfn ../lib/node_modules/pnpm/bin/pnpm.cjs "${NPM_GLOBAL}/bin/pnpm"
    ln -sfn ../lib/node_modules/pnpm/bin/pnpx.cjs "${NPM_GLOBAL}/bin/pnpx"
    chmod +x "${NPM_GLOBAL}/lib/node_modules/nrm/dist/index.js" \
             "${NPM_GLOBAL}/lib/node_modules/pnpm/bin/"*.cjs || true
    log "ok: npm-global via host copy"
    return 0
  fi

  if command -v npm >/dev/null 2>&1; then
    npm_bin="$(command -v npm)"
  elif [[ -x "${HOME}/.nvm/versions/node/v${NODE_VERSION}/bin/npm" ]]; then
    npm_bin="${HOME}/.nvm/versions/node/v${NODE_VERSION}/bin/npm"
  else
    log "error: need host nrm/pnpm modules or npm"; exit 1
  fi

  rm -rf "${NPM_GLOBAL}"
  mkdir -p "${NPM_GLOBAL}" "$cache"
  # Pin pnpm 9: store layout is v3 (matches clone-pnpm-store / host seed).
  log "npm install -g --prefix npm-global nrm pnpm@9.15.9 (prefer-offline)"
  (
    unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY
    export NPM_CONFIG_REGISTRY=https://registry.npmmirror.com
    export NPM_CONFIG_FETCH_TIMEOUT=20000
    "$npm_bin" install -g --prefix "${NPM_GLOBAL}" --cache "$cache" --prefer-offline \
      --no-audit --no-fund nrm pnpm@9.15.9
  ) || (
    export NPM_CONFIG_REGISTRY=https://registry.npmmirror.com
    export http_proxy="$PROXY_HTTP" https_proxy="$PROXY_HTTPS" \
           HTTP_PROXY="$PROXY_HTTP" HTTPS_PROXY="$PROXY_HTTPS"
    "$npm_bin" install -g --prefix "${NPM_GLOBAL}" --cache "$cache" --prefer-offline \
      --no-audit --no-fund nrm pnpm@9.15.9
  )
  log "ok: npm-global via npm"
}

vendor_npm_global

# ---------------------------------------------------------------------------
# Shared pnpm store — seed via host store (--prefer-offline), then clone a
# lockfile subset into vendor/pnpm-store (not the whole multi-GB host store).
# Image keeps /var/cache/pnpm/store; apps use --prefer-offline by default
# (miss → online via nrm/registry). Optional --offline for airgap builds.
# ---------------------------------------------------------------------------
vendor_pnpm_store() {
  local src="${ROOT}/minimal"
  local seed="${VENDOR}/minimal-seed"
  local store="${VENDOR}/pnpm-store"
  local stamp="${VENDOR}/pnpm-store.stamp"
  local clone="${ROOT}/scripts/clone-pnpm-store.py"
  local pnpm_bin="" host_store=""

  if [[ ! -f "${src}/package.json" ]]; then
    log "error: missing ${src}/package.json"
    exit 1
  fi
  if [[ ! -f "$clone" ]]; then
    log "error: missing $clone"
    exit 1
  fi

  if [[ -f "$stamp" && -d "${store}/v3/files" && "${FORCE:-0}" != 1 ]]; then
    if cmp -s "${src}/package.json" "${VENDOR}/minimal/package.json" 2>/dev/null; then
      log "skip (exists): vendor/pnpm-store"
      return 0
    fi
  fi

  if command -v pnpm >/dev/null 2>&1; then
    pnpm_bin="$(command -v pnpm)"
  elif [[ -x "${VENDOR}/npm-global/bin/pnpm" ]]; then
    pnpm_bin="${VENDOR}/npm-global/bin/pnpm"
  else
    log "error: pnpm required to seed pnpm store"
    exit 1
  fi

  host_store="$("$pnpm_bin" store path 2>/dev/null || true)"
  if [[ -z "$host_store" || ! -d "$host_store" ]]; then
    host_store="${HOME}/.local/share/pnpm/store/v3"
  fi
  # pnpm store path returns …/store/v3; parent is the configured store-dir root.
  local host_store_dir
  host_store_dir="$(dirname "$host_store")"

  log "pnpm install (seed against host store) -> ${host_store}"
  rm -rf "$seed" "$store"
  mkdir -p "$seed"
  mkdir -p "${VENDOR}/minimal"
  cp -a "${src}/package.json" "${VENDOR}/minimal/"
  [[ -f "${src}/.npmrc" ]] && cp -a "${src}/.npmrc" "${VENDOR}/minimal/" || true
  [[ -f "${src}/README.md" ]] && cp -a "${src}/README.md" "${VENDOR}/minimal/"
  cp -a "${src}/package.json" "${seed}/"
  cat >"${seed}/.npmrc" <<EOF
store-dir=${host_store_dir}
registry=https://registry.npmmirror.com
EOF

  (
    unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY
    export NPM_CONFIG_REGISTRY=https://registry.npmmirror.com
    export PRISMA_CLI_BINARY_TARGETS=rhel-openssl-3.0.x
    cd "$seed"
    if ! "$pnpm_bin" install --prod --prefer-offline; then
      export http_proxy="$PROXY_HTTP" https_proxy="$PROXY_HTTPS" \
             HTTP_PROXY="$PROXY_HTTP" HTTPS_PROXY="$PROXY_HTTPS"
      "$pnpm_bin" install --prod --prefer-offline || "$pnpm_bin" install --prod
    fi
  )

  [[ -f "${seed}/pnpm-lock.yaml" ]] || { log "error: seed lockfile missing"; exit 1; }
  cp -a "${seed}/pnpm-lock.yaml" "${VENDOR}/minimal/"

  log "clone lockfile subset ${host_store} -> ${store}"
  if ! python3 "$clone" \
    --lockfile "${seed}/pnpm-lock.yaml" \
    --src-store "$host_store" \
    --dst-store "$store"
  then
    log "error: clone-pnpm-store incomplete (missing packages in host store)"
    exit 1
  fi

  # Drop seed tree — only the cloned store + minimal metadata ship in context.
  rm -rf "$seed"

  {
    echo "built_at=$(date -Iseconds)"
    echo "pnpm=$("$pnpm_bin" -v 2>/dev/null || echo unknown)"
    echo "store_size=$(du -sh "$store" | awk '{print $1}')"
    echo "mode=store-subset-from-host (prefer-offline seed; node_modules not kept)"
    echo "app_install=pnpm install --prod --prefer-offline  # or --offline if PNPM_OFFLINE=1"
  } | tee "${VENDOR}/minimal/MANIFEST.txt"
  date -Iseconds >"$stamp"
  log "ok: vendor/pnpm-store ($(du -sh "$store" | awk '{print $1}'))"
}

vendor_pnpm_store

# Record versions for the Dockerfile / debugging
cat >"${VENDOR}/versions.env" <<EOF
NODE_VERSION=${NODE_VERSION}
NVM_VERSION=${NVM_VERSION}
ERLANG_RPM=${ERLANG_RPM}
RABBIT_RPM=${RABBIT_RPM}
NPM_CACHE=${NPM_CACHE:-}
PNPM_STORE=/var/cache/pnpm/store
MINIMAL_STORE=1
EOF

log "done -> ${VENDOR}"
