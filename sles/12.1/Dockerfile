ARG VERSION=1.0
ARG DISTRO_SPEC=sles:12.1
ARG LRM_BWSEL_OPTS=""

# SLES 12 SP1 twin: openSUSE Leap 42.1 (glibc 2.22) via opensuse/archive:42.1
FROM opensuse/archive:42.1

ARG VERSION
ARG DISTRO_SPEC
ARG LRM_BWSEL_OPTS=""

LABEL maintainer="Lenik <lenik@bodz.net>"
LABEL description="SLES-family & uni tools (openSUSE Leap twin)"
LABEL version=${VERSION}

ENV PATH="/usr/local/bin:${PATH}"
ENV LRM_GETBAR=getbar


# Dockerd HTTP_PROXY is for image pulls only — do not proxy container/build RUN traffic.
ENV HTTP_PROXY= HTTPS_PROXY= http_proxy= https_proxy= NO_PROXY=* no_proxy=*

# ---------------------------------------------------------------------------
# 1. Bootstrap zypper — China openSUSE mirrors (no SCC required).
# ---------------------------------------------------------------------------
RUN --mount=type=cache,id=sles-12.1-zypp,target=/var/cache/zypp,sharing=locked \
    --mount=type=bind,source=etc,target=/tmp/src_etc \
    --mount=type=bind,from=leap42_repo,source=/,target=/src/leap42.1-repo,ro \
    mkdir -p /etc/zypp/repos.d/bak \
    && (shopt -s nullglob; for f in /etc/zypp/repos.d/*.repo; do mv -f "$f" /etc/zypp/repos.d/bak/; done) \
    && printf '%s\n' \
        '[lrm-local-oss]' \
        'name=lrm local Leap 42.1 OSS (prefetched via axel -n 16)' \
        'enabled=1' \
        'autorefresh=0' \
        'baseurl=file:///src/leap42.1-repo/x86_64' \
        'type=rpm-md' \
        'gpgcheck=0' \
        'priority=1' \
        > /etc/zypp/repos.d/lrm-local.repo \
    && zypper --non-interactive --gpg-auto-import-keys refresh \
    && zypper --non-interactive install --no-recommends bash ca-certificates curl \
    && rm -f /etc/zypp/repos.d/lrm-local.repo

# ---------------------------------------------------------------------------
# 2. Suite-specific getbar/lrm (built on host with build4 → build-<arch>/)
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# 3. Leap 42.1 is discontinued — skip lrm bwsel (maps to wrong 42.3 + HTTPS/SSL pain).
#    Keep getbar/lrm in the image for runtime; use prefetched local OSS + ftp5 HTTP.
# ---------------------------------------------------------------------------
RUN mkdir -p /etc/zypp/repos.d \
    && printf "%s\n" "Leap 42.1: skip bwsel; packages come from axel-prefetched local OSS repo"

# ---------------------------------------------------------------------------
# 4. Refresh from selected mirror, install runtime deps + essentials.
# ---------------------------------------------------------------------------
RUN --mount=type=cache,id=sles-12.1-zypp-v2,target=/var/cache/zypp,sharing=locked \
    --mount=type=bind,source=etc,target=/tmp/src_etc \
    --mount=type=bind,from=leap42_repo,source=/,target=/src/leap42.1-repo,ro \
    printf '%s\n' \
        '[lrm-local-oss]' \
        'name=lrm local Leap 42.1 OSS (prefetched)' \
        'enabled=1' \
        'autorefresh=0' \
        'baseurl=file:///src/leap42.1-repo/x86_64' \
        'type=rpm-md' \
        'gpgcheck=0' \
        'priority=1' \
        > /etc/zypp/repos.d/lrm-local.repo \
    && zypper --non-interactive --gpg-auto-import-keys refresh \
    && zypper --non-interactive install --no-recommends \
        libcurl4 libglib-2_0-0 libicu zlib \
        bash-completion curl findutils git gzip iproute2 less \
        man nano procps rsync tar which jq ripgrep \
        || zypper --non-interactive install --no-recommends \
        curl findutils git less nano procps rsync tar which jq ripgrep \
        || true \
    && rm -f /etc/zypp/repos.d/lrm-local.repo \
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
