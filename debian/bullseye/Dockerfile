# syntax=docker/dockerfile:1
ARG VERSION=1.0
ARG DISTRO_SPEC=debian:bullseye
# Some CN mirrors (e.g. 163) no longer ship bullseye-backports.
ARG LRM_BWSEL_OPTS="--no-backports"

FROM debian:bullseye

ARG VERSION
ARG DISTRO_SPEC
ARG LRM_BWSEL_OPTS="--no-backports"

LABEL maintainer="Lenik <lenik@bodz.net>"
LABEL description="Debian/GNU-Linux & uni tools"
LABEL version=${VERSION}

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/usr/local/bin:${PATH}"
ENV LRM_GETBAR=getbar

# ---------------------------------------------------------------------------
# 1. Bootstrap apt — only enough to run lrm selection.
# ---------------------------------------------------------------------------
RUN --mount=type=cache,id=bullseye,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=bullseye,target=/var/lib/apt/lists,sharing=locked \
    --mount=type=bind,source=etc,target=/tmp/src_etc \
    cp /tmp/src_etc/apt/bootstrap/sources.list /etc/apt/sources.list \
    && cp -a /tmp/src_etc/apt/apt.conf.d/. /etc/apt/apt.conf.d/ \
    && rm -f /etc/apt/sources.list.d/debian.sources \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
    && rm -f /etc/apt/sources.list

# ---------------------------------------------------------------------------
# 2. Suite-specific getbar/lrm (built on host with build4 → vendor/)
# ---------------------------------------------------------------------------
COPY vendor/ /usr/local/
RUN ldconfig \
    && chmod +x /usr/local/bin/getbar /usr/local/bin/lrm \
           /usr/local/bin/apt-via-lrm.sh /usr/local/bin/apt-bootstrap-ca.sh \
    && (test -x /usr/local/bin/drm && chmod +x /usr/local/bin/drm || true) \
    && lrm --version

# ---------------------------------------------------------------------------
# 3. Select fastest mirror with lrm bwsel (inside the image)
# Some CN mirrors (e.g. 163) no longer ship bullseye-backports.
# ---------------------------------------------------------------------------
RUN apt-via-lrm.sh "${DISTRO_SPEC}" --no-backports

# ---------------------------------------------------------------------------
# 4. Refresh from selected mirror, install runtime deps + essentials.
# ---------------------------------------------------------------------------
RUN --mount=type=cache,id=bullseye-v2,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=bullseye-v2,target=/var/lib/apt/lists,sharing=locked \
    --mount=type=bind,source=etc,target=/tmp/src_etc \
    apt-bootstrap-ca.sh \
    && apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
        libcurl4 \
        libglib2.0-0 \
        libicu67 \
        zlib1g \
        bash-completion \
        curl \
        findutils \
        git \
        git-man \
        gnupg \
        iproute2 \
        less \
        locales \
        man-db \
        manpages \
        manpages-dev \
        nano \
        procps \
        rsync \
    && getbar --version \
    && rsync -av --exclude bak --exclude bootstrap /tmp/src_etc/ /etc/ \
    && apt-get update

ENV TZ=Asia/Shanghai
ENV LANG=en_US.utf8

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    && sed -i \
        -e '/ar_EG.UTF-8/s/^# //g' \
        -e '/de_DE.UTF-8/s/^# //g' \
        -e '/en_US.UTF-8/s/^# //g' \
        -e '/eo.UTF-8/s/^# //g' \
        -e '/he_IL.UTF-8/s/^# //g' \
        -e '/it_IT.UTF-8/s/^# //g' \
        -e '/ja_JP.UTF-8/s/^# //g' \
        -e '/ko_KR.UTF-8/s/^# //g' \
        -e '/ru_RU.UTF-8/s/^# //g' \
        -e '/th_TH.UTF-8/s/^# //g' \
        -e '/vi_VN.UTF-8/s/^# //g' \
        -e '/zh_CN.UTF-8/s/^# //g' \
        -e '/zh_TW.UTF-8/s/^# //g' \
        /etc/locale.gen \
    && locale-gen

COPY --from=host_opt ./java/jdk-21.0.7 /opt/java/jdk-21.0.7

RUN groupadd --gid 700 dev; \
    groupmod --gid 300 wget; \
    usermod --uid 300 wget; \
    useradd --uid 999 -g dev -m -p l. lenik

RUN mkdir -p /home/lenik/.ssh && chmod 700 /home/lenik/.ssh
COPY --chown=lenik:dev authorized_keys /home/lenik/.ssh/authorized_keys
RUN chmod 600 /home/lenik/.ssh/authorized_keys

ENTRYPOINT ["/bin/bash", "-i"]
