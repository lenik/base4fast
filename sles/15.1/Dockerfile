# syntax=docker/dockerfile:1
ARG VERSION=1.0
ARG DISTRO_SPEC=sles:15.1
ARG LRM_BWSEL_OPTS=""

# SLES 15 SP1 era via openSUSE Leap 15.1 (BCI 15.1 tag no longer published).
FROM opensuse/leap:15.1

ARG VERSION
ARG DISTRO_SPEC
ARG LRM_BWSEL_OPTS=""

LABEL maintainer="Lenik <lenik@bodz.net>"
LABEL description="SLES-family & uni tools"
LABEL version=${VERSION}

ENV PATH="/usr/local/bin:${PATH}"
ENV LRM_GETBAR=getbar

# ---------------------------------------------------------------------------
# 1. Bootstrap zypper — China openSUSE mirrors (no SCC required).
# ---------------------------------------------------------------------------
RUN --mount=type=cache,id=sles-15.1-zypp,target=/var/cache/zypp,sharing=locked \
    --mount=type=bind,source=etc,target=/tmp/src_etc \
    mkdir -p /etc/zypp/repos.d/bak \
    && (shopt -s nullglob; for f in /etc/zypp/repos.d/*.repo; do mv -f "$f" /etc/zypp/repos.d/bak/; done) \
    && cp /tmp/src_etc/zypp/bootstrap/lrm-bootstrap.repo /etc/zypp/repos.d/ \
    && zypper --non-interactive --gpg-auto-import-keys refresh \
    && zypper --non-interactive install --no-recommends bash ca-certificates \
    && rm -f /etc/zypp/repos.d/lrm-bootstrap.repo

# ---------------------------------------------------------------------------
# 2. Suite-specific getbar/lrm (built on host with build4 → vendor/)
# ---------------------------------------------------------------------------
COPY vendor/ /usr/local/
RUN echo /usr/local/lib > /etc/ld.so.conf.d/local.conf \
    && ldconfig \
    && chmod +x /usr/local/bin/getbar /usr/local/bin/lrm \
           /usr/local/bin/zypper-via-lrm.sh \
    && (test -x /usr/local/bin/drm && chmod +x /usr/local/bin/drm || true) \
    && lrm --version

# ---------------------------------------------------------------------------
# 3. Select fastest mirror with lrm bwsel (inside the image)
# ---------------------------------------------------------------------------
RUN zypper-via-lrm.sh "${DISTRO_SPEC}" ${LRM_BWSEL_OPTS}

# ---------------------------------------------------------------------------
# 4. Refresh from selected mirror, install runtime deps + essentials.
# ---------------------------------------------------------------------------
RUN --mount=type=cache,id=sles-15.1-zypp-v2,target=/var/cache/zypp,sharing=locked \
    --mount=type=bind,source=etc,target=/tmp/src_etc \
    zypper --non-interactive --gpg-auto-import-keys refresh \
    && zypper --non-interactive update \
    && zypper --non-interactive install --no-recommends \
        libcurl4 libglib-2_0-0 libicu zlib \
        bash-completion curl findutils git gzip iproute2 less \
        man nano procps rsync tar which \
        || zypper --non-interactive install --no-recommends \
        curl findutils git less nano procps rsync tar which \
    && getbar --version \
    && mkdir -p /etc/bashrc.d \
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

COPY --from=host_opt ./java/jdk-17 /opt/java/jdk-17

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

ENTRYPOINT ["/bin/bash", "-i"]
