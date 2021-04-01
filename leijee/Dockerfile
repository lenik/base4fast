FROM leideb:buster
MAINTAINER Lenik <lenik@bodz.net>
LABEL \
    description = "Lenik's Java Web Server" \
    version = "1.0"

#RUN sudo curl https://www.pgadmin.org/static/packages_pgadmin_org.pub | sudo apt-key add; \
#    sudo sh -c 'echo "deb https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$(lsb_release -cs) pgadmin4 main" > /etc/apt/sources.list.d/pgadmin4.list && apt update'

ENV PG_MAJOR 11
ENV PATH /usr/lib/postgresql/$PG_MAJOR/bin:$PATH

RUN apt-get update \
	&& apt-get install -y postgresql-common \
	&& sed -ri 's/#(create_main_cluster) .*$/\1 = false/' /etc/postgresql-common/createcluster.conf \
    && apt-get install -y --force-yes \
        libapache2-mod-wsgi-py3 \
        postgresql-11 \
        postgresql-plperl-11 \
        postgresql-plpython-11

# make the sample config easier to munge (and "correct by default")
RUN mv -v /usr/share/postgresql/$PG_MAJOR/postgresql.conf.sample /usr/share/postgresql/ \
	&& ln -sv ../postgresql.conf.sample /usr/share/postgresql/$PG_MAJOR/ \
	&& sed -ri "s!^#?(listen_addresses)\s*=\s*\S+.*!\1 = '*'!" /usr/share/postgresql/postgresql.conf.sample

COPY deb/ /opt/deb/
RUN dpkg -i /opt/deb/*.deb; \
    apt-get install -y --force-yes -f; \
    rm -fr /opt/deb

ENV PGDATA  /var/pgdata
EXPOSE 5432

COPY scripts /scripts
#ENTRYPOINT ["/bin/bash", "-i"]
ENTRYPOINT ["/scripts/docker-start"]

#, "sudo -upostgres psql"]
