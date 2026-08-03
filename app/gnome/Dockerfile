FROM leideb:stable
MAINTAINER Lenik <lenik@bodz.net>

RUN apt-get update || true
RUN apt-get install -y --force-yes \
    gnome \
    gedit

LABEL \
    description = "leideb with GNOME desktop" \
    version = "1.0"
