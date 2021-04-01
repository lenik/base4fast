FROM centos:latest
MAINTAINER Lenik <lenik@bodz.net>
LABEL \
    description = "CentOS with mirror repos in China" \
    version = "1"

ADD build/ /build/
RUN /build/01_163.sh; yum clean all; yum makecache; rm -fr /build

WORKDIR /root

