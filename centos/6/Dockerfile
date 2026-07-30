# syntax=docker/dockerfile:1
ARG VERSION=2.0
ARG DISTRO_SPEC=centos:6

FROM quay.io/centos/centos:6

ARG VERSION
ARG DISTRO_SPEC

LABEL maintainer="Lenik <lenik@bodz.net>"
LABEL description="CentOS/RHEL-family & uni tools"
LABEL version=${VERSION}

ENV PATH="/usr/local/bin:${PATH}"
ENV LRM_GETBAR=getbar

# ---------------------------------------------------------------------------
# 1. Bootstrap yum from HTTP centos-vault (CentOS 6 TLS is often too old).
#    Keep these repos permanently — no bwsel/getbar (glibc too old for
#    getbar/lrm built on CentOS 7+).
# ---------------------------------------------------------------------------
RUN --mount=type=cache,id=centos-6-yum,target=/var/cache/yum,sharing=locked \
    --mount=type=bind,source=etc,target=/tmp/src_etc \
    mkdir -p /etc/yum.repos.d/bak \
    && (shopt -s nullglob; for f in /etc/yum.repos.d/*.repo; do mv -f "$f" /etc/yum.repos.d/bak/; done) \
    && cp /tmp/src_etc/yum/bootstrap/lrm-bootstrap.repo /etc/yum.repos.d/lrm.repo \
    && printf '\nexclude=*.i386 *.i686\nmultilib_policy=best\n' >> /etc/yum.conf \
    && yum -y --exclude='*.i386' --exclude='*.i686' --skip-broken install bash ca-certificates \
    && yum clean all || true

# ---------------------------------------------------------------------------
# 2. Stub getbar/lrm (vendor from build-lrm-tools-stub.sh).
# ---------------------------------------------------------------------------
COPY vendor/ /usr/local/
RUN echo /usr/local/lib > /etc/ld.so.conf.d/local.conf \
    && ldconfig \
    && chmod +x /usr/local/bin/lrm /usr/local/bin/yum-via-lrm.sh /usr/local/bin/getbar \
    && (test -x /usr/local/bin/drm && chmod +x /usr/local/bin/drm || true) \
    && lrm --version \
    && getbar --version

# ---------------------------------------------------------------------------
# 3. Install runtime deps from fixed HTTP vault mirrors.
# ---------------------------------------------------------------------------
RUN --mount=type=cache,id=centos-6-yum-v2,target=/var/cache/yum,sharing=locked \
    --mount=type=bind,source=etc,target=/tmp/src_etc \
    yum -y --exclude='*.i386' --exclude='*.i686' --skip-broken update \
    && yum -y --exclude='*.i386' --exclude='*.i686' --skip-broken install \
          libcurl glib2 zlib \
          bash-completion curl findutils git gnupg2 iproute less \
          man nano procps rsync tar which openssl \
    && mkdir -p /etc/bashrc.d \
    && cp /tmp/src_etc/bash.bashrc /etc/bashrc.base4fast \
    && echo '[ -f /etc/bashrc.base4fast ] && . /etc/bashrc.base4fast' >> /etc/bashrc \
    && yum clean all || true

ENV TZ=Asia/Shanghai
ENV LANG=en_US.utf8

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    && (localedef -i en_US -f UTF-8 en_US.UTF-8 || true)

COPY --from=host_opt ./java/jdk-11 /opt/java/jdk-11

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
