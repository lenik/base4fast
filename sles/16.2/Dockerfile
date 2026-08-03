ARG VERSION=1.0
ARG DISTRO_SPEC=sles:16.2
ARG LRM_BWSEL_OPTS=""

# Official SLE BCI. Tag 16.2 is not published yet; use 16.1.
FROM registry.suse.com/bci/bci-base:16.1

ARG VERSION
ARG DISTRO_SPEC
ARG LRM_BWSEL_OPTS=""

LABEL maintainer="Lenik <lenik@bodz.net>"
LABEL description="SLES-family & uni tools"
LABEL version=${VERSION}

ENV PATH="/usr/local/bin:${PATH}"
ENV LRM_GETBAR=getbar


# Dockerd HTTP_PROXY is for image pulls only — do not proxy container/build RUN traffic.
ENV HTTP_PROXY= HTTPS_PROXY= http_proxy= https_proxy= NO_PROXY=* no_proxy=*

# Keep stock SLE_BCI (public-dl.suse.com) — official packages.
RUN --mount=type=cache,id=sles-16.2-zypp,target=/var/cache/zypp,sharing=locked \
    zypper --non-interactive --gpg-auto-import-keys refresh \
    && zypper --non-interactive install --no-recommends bash ca-certificates curl

ARG TARGETARCH=amd64
COPY build-${TARGETARCH}/ /usr/local/
RUN echo /usr/local/lib > /etc/ld.so.conf.d/local.conf \
    && ldconfig \
    && chmod +x /usr/local/bin/getbar /usr/local/bin/lrm \
           /usr/local/bin/zypper-via-lrm.sh \
           /usr/local/bin/configrepo.sh /usr/local/bin/configrepo \
           /usr/local/bin/install-net-tools.sh \
    && (test -x /usr/local/bin/drm && chmod +x /usr/local/bin/drm || true) \
    && lrm --version

# ---------------------------------------------------------------------------
# Local ISO mirror (soft-skip if unavailable) before package install.
# ---------------------------------------------------------------------------
RUN configrepo.sh

RUN --mount=type=cache,id=sles-16.2-zypp-v2,target=/var/cache/zypp,sharing=locked \
    --mount=type=bind,source=etc,target=/tmp/src_etc \
    zypper --non-interactive --gpg-auto-import-keys refresh \
    && zypper --non-interactive update \
    && zypper --non-interactive install --no-recommends \
        libcurl4 libglib-2_0-0 libicu zlib \
        bash-completion curl findutils git gzip iproute2 less \
        man procps rsync tar which jq ripgrep \
        || zypper --non-interactive install --no-recommends \
        curl findutils git less procps rsync tar which jq ripgrep \
    && getbar --version \
    && mkdir -p /etc/bashrc.d \
    && cp /tmp/src_etc/bash_alias /etc/bash_alias \
    && cp /tmp/src_etc/bash.bashrc /etc/bashrc.base4fast \
    && (grep -q bashrc.base4fast /etc/bash.bashrc 2>/dev/null \
        || echo '[ -f /etc/bashrc.base4fast ] && . /etc/bashrc.base4fast' >> /etc/bash.bashrc) \
    && (grep -q bashrc.base4fast /etc/bashrc 2>/dev/null \
        || echo '[ -f /etc/bashrc.base4fast ] && . /etc/bashrc.base4fast' >> /etc/bashrc || true)

ENV TZ=Asia/Shanghai
ENV LANG=en_US.utf8

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    && (localedef -i en_US -f UTF-8 en_US.UTF-8 || true)

RUN install-net-tools.sh

RUN groupadd -g 700 dev 2>/dev/null || groupadd --gid 700 dev || true; \
    if ! id -u lenik >/dev/null 2>&1; then \
      existing="$(getent passwd 999 | cut -d: -f1 || true)"; \
      if [ -n "$existing" ] && [ "$existing" != lenik ]; then \
        userdel -r "$existing" 2>/dev/null || userdel "$existing" 2>/dev/null || true; \
      fi; \
      useradd -u 999 -g dev -m -p l. lenik; \
    fi

RUN mkdir -p /home/lenik/.ssh && chmod 700 /home/lenik/.ssh
COPY --chown=lenik:dev authorized_keys /home/lenik/.ssh/authorized_keys
RUN chmod 600 /home/lenik/.ssh/authorized_keys
