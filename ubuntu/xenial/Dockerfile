# syntax=docker/dockerfile:1
ARG VERSION=1.0
ARG BASE_IMAGE=ubuntu:xenial
ARG DISTRO_SPEC=ubuntu:xenial
ARG LRM_BWSEL_OPTS="--no-backports --no-src"

FROM ${BASE_IMAGE}

ARG VERSION
ARG DISTRO_SPEC
ARG LRM_BWSEL_OPTS="--no-backports --no-src"

LABEL maintainer="Lenik <lenik@bodz.net>"
LABEL description="Ubuntu LTS with getbar/lrm (16.04)"
LABEL version=${VERSION}

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/usr/local/bin:${PATH}"
ENV LRM_GETBAR=getbar


# Dockerd HTTP_PROXY is for image pulls only — do not proxy container/build RUN traffic.
ENV HTTP_PROXY= HTTPS_PROXY= http_proxy= https_proxy= NO_PROXY=* no_proxy=*

# ---------------------------------------------------------------------------
# 1. Bootstrap apt — only enough to run lrm selection.
# ---------------------------------------------------------------------------
RUN --mount=type=cache,id=ubuntu-xenial,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=ubuntu-xenial,target=/var/lib/apt/lists,sharing=locked \
    --mount=type=bind,source=etc,target=/tmp/src_etc \
    cp /tmp/src_etc/apt/bootstrap/sources.list /etc/apt/sources.list \
    && cp -a /tmp/src_etc/apt/apt.conf.d/. /etc/apt/apt.conf.d/ \
    && rm -f /etc/apt/sources.list.d/ubuntu.sources \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
    && rm -f /etc/apt/sources.list

# ---------------------------------------------------------------------------
# 2. Suite-specific getbar/lrm (built on host with build4 → build-<arch>/)
# ---------------------------------------------------------------------------
ARG TARGETARCH=amd64
COPY build-${TARGETARCH}/ /usr/local/
RUN ldconfig \
    && chmod +x /usr/local/bin/getbar /usr/local/bin/lrm \
           /usr/local/bin/apt-via-lrm.sh /usr/local/bin/apt-bootstrap-ca.sh \
           /usr/local/bin/configrepo.sh /usr/local/bin/configrepo \
           /usr/local/bin/install-net-tools.sh \
    && (test -x /usr/local/bin/drm && chmod +x /usr/local/bin/drm || true) \
    && lrm --version

# ---------------------------------------------------------------------------
# Local ISO mirror (configrepo) then lrm bwsel.
# ---------------------------------------------------------------------------
RUN configrepo.sh

RUN apt-via-lrm.sh "${DISTRO_SPEC}" ${LRM_BWSEL_OPTS}

# ---------------------------------------------------------------------------
# 4. Refresh from selected mirror, install getbar/lrm runtime deps.
# ---------------------------------------------------------------------------
RUN --mount=type=cache,id=ubuntu-xenial-v2,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=ubuntu-xenial-v2,target=/var/lib/apt/lists,sharing=locked \
    --mount=type=bind,source=etc,target=/tmp/src_etc \
    apt-bootstrap-ca.sh \
    && apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
        libcurl3 \
        libglib2.0-0 \
        libicu55 \
        zlib1g \
    && getbar --version \
    && (cd /tmp/src_etc && tar cf - --exclude=bak --exclude=bootstrap .) | (cd /etc && tar xpf -) \
    && apt-get update

RUN install-net-tools.sh

RUN groupadd --gid 700 dev; \
    (getent group wget >/dev/null && groupmod --gid 300 wget || true); \
    (id -u wget >/dev/null 2>&1 && usermod --uid 300 wget || true); \
    useradd --uid 999 -g dev -m -p l. lenik

RUN mkdir -p /home/lenik/.ssh && chmod 700 /home/lenik/.ssh
COPY --chown=lenik:dev authorized_keys /home/lenik/.ssh/authorized_keys
RUN chmod 600 /home/lenik/.ssh/authorized_keys

ENTRYPOINT ["/bin/bash", "-i"]
