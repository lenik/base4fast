FROM java:7
MAINTAINER Lenik <lenik@bodz.net>

ENV ARCHIVA_VERSION=2.2.1 \
    ARCHIVA_SHA1=5a5f6cbda43cb185840e406e0675bc8029e29be9 \
    ARCHIVA_BASE=/var/archiva

# Download archiva and extract to /tmp...
RUN curl -sSLo /tmp/apache-archiva-$ARCHIVA_VERSION-bin.tar.gz http://mir2.ovh.net/ftp.apache.org/dist/archiva/$ARCHIVA_VERSION/binaries/apache-archiva-$ARCHIVA_VERSION-bin.tar.gz \
  && echo "$ARCHIVA_SHA1 /tmp/apache-archiva-$ARCHIVA_VERSION-bin.tar.gz" | sha1sum -c \
  && tar -xf /tmp/apache-archiva-$ARCHIVA_VERSION-bin.tar.gz --directory /opt \
  && rm /tmp/apache-archiva-$ARCHIVA_VERSION-bin.tar.gz

WORKDIR /opt/apache-archiva-$ARCHIVA_VERSION

# Force to use ARCHIVA_BASE.
RUN mkdir -p $ARCHIVA_BASE; \
    sed -i "/set.default.ARCHIVA_BASE/c\set.default.ARCHIVA_BASE=$ARCHIVA_BASE" conf/wrapper.conf; \
    (cd $ARCHIVA_BASE; mkdir logs data temp conf); \
    mv conf/* $ARCHIVA_BASE/conf; \
    rmdir logs conf temp; \
    ln -s $ARCHIVA_BASE/logs logs; \
    ln -s $ARCHIVA_BASE/conf conf; \
    ln -s $ARCHIVA_BASE/data data; \
    ln -s $ARCHIVA_BASE/temp temp; \
    addgroup --gid 700 dev; \
    adduser --uid 8146 --gid 700 archiva; \
    chown -R archiva:dev $ARCHIVA_BASE

USER archiva
RUN ln -s /repo/m2/archiva /home/archiva/.m2

VOLUME /var/archiva
VOLUME /repo/m2

EXPOSE 8080
ENTRYPOINT bin/archiva console

