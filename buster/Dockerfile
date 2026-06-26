# syntax=docker/dockerfile:1
ARG VERSION=2.0

FROM debian:buster

ARG VERSION

LABEL maintainer="Lenik <lenik@bodz.net>"
LABEL description="Debian/GNU-Linux & uni tools"
LABEL version=${VERSION}

# Install basic system, networking, and utility tools.
# BuildKit cache mounts are leveraged to store package metadata and downloaded .deb layers persistently on the host, 
# significantly speeding up subsequent rebuilds while keeping the final image layers lightweight.
RUN --mount=type=cache,id=buster,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=buster,target=/var/lib/apt/lists,sharing=locked \
    --mount=type=bind,source=etc,target=/tmp/src_etc \
    cp /tmp/src_etc/apt/sources.list /etc/apt/ && \
    apt-get update && apt-get install -y \
        bash \
        bash-completion \
        ca-certificates \
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
        rsync && \
    rsync -av /tmp/src_etc/ /etc/ && \
    apt-get update && apt-get upgrade -y

# Configure language locales for international environments (English, Chinese, Japanese, Korean, Thai).
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

# Deploy the localized Java Development Kit deployment package.
COPY --from=host_opt ./java/jdk-17 /opt/java/jdk-17

# Set up specific GIDs/UIDs for system users and provisions the primary non-root development user account ('lenik').
RUN groupadd --gid 700 dev; \
    groupmod --gid 300 wget; \
    usermod --uid 300 wget; \
    useradd --uid 999 -g dev -m -p l. lenik

# Provision Secure Shell (SSH) access permissions for the development user.
# Strict POSIX permission sets (700 and 600) are explicitly defined to prevent SSH authorization rejection faults.
RUN mkdir -p /home/lenik/.ssh && chmod 700 /home/lenik/.ssh
COPY --chown=lenik:dev authorized_keys /home/lenik/.ssh/authorized_keys
RUN chmod 600 /home/lenik/.ssh/authorized_keys

# Initialize an interactive bash instance as the runtime entry point.
ENTRYPOINT ["/bin/bash", "-i"]

