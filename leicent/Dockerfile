FROM centos-cn:latest
MAINTAINER Lenik <lenik@bodz.net>

RUN yum groupinstall -y \
        'Minimal Install' \
        'Compute Node' \
        'File and Print Server' \
        'Basic Web Server'

RUN yum install -y \
        bash-completion \
        dos2unix \
        file \
        gcc \
        iproute \
        make \
        net-tools \
        perl \
        python \
        ruby \
        sudo \
        tree \
        which

# Setup bash-aliases, etc.
ADD build/ /build/
RUN /build/baseinst.sh; rm -fr /build

LABEL \
    description = "Lenik's CentOS dev build" \
    version = "1.0"
