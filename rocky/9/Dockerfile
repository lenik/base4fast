ARG VERSION=1.0
ARG DISTRO_SPEC=rocky:9
ARG LRM_BWSEL_OPTS="--everything --epel"

FROM quay.io/rockylinux/rockylinux:9

ARG VERSION
ARG DISTRO_SPEC
ARG LRM_BWSEL_OPTS="--everything --epel"

LABEL maintainer="Lenik <lenik@bodz.net>"
LABEL description="Rocky Linux & uni tools"
LABEL version=${VERSION}

ENV PATH="/usr/local/bin:${PATH}"
ENV LRM_GETBAR=getbar


# Dockerd HTTP_PROXY is for image pulls only — do not proxy container/build RUN traffic.
ENV HTTP_PROXY= HTTPS_PROXY= http_proxy= https_proxy= NO_PROXY=* no_proxy=*

# ---------------------------------------------------------------------------
# 1. Bootstrap dnf — only enough to run lrm selection.
# ---------------------------------------------------------------------------
RUN --mount=type=cache,id=rocky-9-yum,target=/var/cache/yum,sharing=locked \
    --mount=type=cache,id=rocky-9-dnf,target=/var/cache/dnf,sharing=locked \
    --mount=type=bind,source=etc,target=/tmp/src_etc \
    mkdir -p /etc/yum.repos.d/bak \
    && (shopt -s nullglob; for f in /etc/yum.repos.d/*.repo; do mv -f "$f" /etc/yum.repos.d/bak/; done) \
    && cp /tmp/src_etc/yum/bootstrap/lrm-bootstrap.repo /etc/yum.repos.d/ \
    && dnf -y --setopt=install_weak_deps=False \
         --setopt=timeout=120 --setopt=minrate=100 --setopt=retries=15 \
         install bash ca-certificates curl \
    && rm -f /etc/yum.repos.d/lrm-bootstrap.repo

# ---------------------------------------------------------------------------
# 2. Suite-specific getbar/lrm (built on host with build4 → build-<arch>/)
# ---------------------------------------------------------------------------
ARG TARGETARCH
COPY build-${TARGETARCH}/ /usr/local/
RUN echo /usr/local/lib > /etc/ld.so.conf.d/local.conf \
    && ldconfig \
    && chmod +x /usr/local/bin/getbar /usr/local/bin/lrm \
           /usr/local/bin/yum-via-lrm.sh \
           /usr/local/bin/configrepo.sh /usr/local/bin/configrepo \
           /usr/local/bin/install-net-tools.sh \
    && (test -x /usr/local/bin/drm && chmod +x /usr/local/bin/drm || true) \
    && lrm --version

# ---------------------------------------------------------------------------
# Local ISO mirror (configrepo) then lrm bwsel.
# ---------------------------------------------------------------------------
RUN configrepo.sh

RUN yum-via-lrm.sh "${DISTRO_SPEC}" ${LRM_BWSEL_OPTS}

# ---------------------------------------------------------------------------
# 4. Refresh from selected mirror, install runtime deps + essentials.
# ---------------------------------------------------------------------------
RUN --mount=type=cache,id=rocky-9-yum-v2,target=/var/cache/yum,sharing=locked \
    --mount=type=cache,id=rocky-9-dnf-v2,target=/var/cache/dnf,sharing=locked \
    --mount=type=bind,source=etc,target=/tmp/src_etc \
    rpm -e --nodeps rocky-repos centos-linux-repos centos-repos centos-stream-repos 2>/dev/null || true; \
    (dnf -y upgrade --allowerasing --nobest \
      --exclude=rocky-repos,centos-linux-repos,centos-repos,centos-stream-repos \
      || true); \
    mkdir -p /etc/yum.repos.d/bak; \
    (shopt -s nullglob; for f in /etc/yum.repos.d/*.repo; do case "$(basename "$f")" in lrm.repo|lrm-bootstrap.repo) continue ;; esac; mv -f "$f" /etc/yum.repos.d/bak/; done); \
    dnf -y --allowerasing --setopt=install_weak_deps=False install \
        libcurl glib2 libicu zlib \
        bash-completion curl findutils git gnupg2 iproute less \
        man-db man-pages nano procps-ng rsync tar which jq ripgrep \
        glibc-langpack-en glibc-langpack-zh glibc-langpack-ja \
        glibc-langpack-ko glibc-langpack-th || \
    dnf -y --allowerasing --setopt=install_weak_deps=False install \
        libcurl glib2 libicu zlib \
        bash-completion curl findutils git gnupg2 iproute less \
        man-db nano procps-ng rsync tar which jq ripgrep \
    && getbar --version \
    && mkdir -p /etc/bashrc.d \
    && cp /tmp/src_etc/bash_alias /etc/bash_alias \
    && cp /tmp/src_etc/bash.bashrc /etc/bashrc.base4fast \
    && echo '[ -f /etc/bashrc.base4fast ] && . /etc/bashrc.base4fast' >> /etc/bashrc

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

ENTRYPOINT ["/bin/bash", "-i"]
