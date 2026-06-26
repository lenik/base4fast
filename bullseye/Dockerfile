FROM debian:bullseye
LABEL \
    maintainer = "Lenik <lenik@bodz.net>" \
    description = "Debian/GNU-Linux & uni tools" \
    version = "2.0"

RUN apt-get update && apt-get install -y \
        bash \
        bash-completion \
        ca-certificates \
        curl \
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
        procps

ENV LANG en_US.utf8
RUN sed -i \
        -e '/en_US.UTF-8/s/^# //g' \
        -e '/zh_CN.UTF-8/s/^# //g' \
        -e '/zh_TW.UTF-8/s/^# //g' \
        -e '/ja_JP.UTF-8/s/^# //g' \
        -e '/ko_KR.UTF-8/s/^# //g' \
        -e '/th_TH.UTF-8/s/^# //g' \
        /etc/locale.gen && \
    locale-gen

COPY apt/sources.list.d/bodz.list /etc/apt/sources.list.d/
RUN apt-get update && apt-get upgrade -y

COPY jdk-21.0.7 /opt/java/jdk-21.0.7

COPY bash.bashrc /etc
COPY docker-clean /etc/apt/apt.conf.d

RUN groupadd --gid 700 dev; \
    groupmod --gid 300 wget; \
    usermod --uid 300 wget; \
    useradd --uid 999 -g dev -m -p l. lenik; \
    mkdir /home/lenik/.ssh
COPY authorized_keys /home/lenik/.ssh

ENTRYPOINT ["/bin/bash", "-i"]
