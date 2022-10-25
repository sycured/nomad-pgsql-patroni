ARG POSTGIS_MAJOR=3

############################
# Build Postgres extensions
############################
FROM citusdata/citus:latest AS ext_build
ARG PGSODIUM_VERSION=v3.0.6
ARG PGVECTOR_VERSION=v0.3.0

RUN set -x \
    && apt-get update -y \
    && apt-get upgrade -y \
    && apt-get install -y git build-essential libipc-run-perl postgresql-server-dev-${PG_MAJOR} libsodium-dev \
    && mkdir /build \
    && cd /build \
    \
    # Build pgvector
    && git clone --branch $PGVECTOR_VERSION https://github.com/ankane/pgvector.git \
    && cd pgvector \
    && make \
    && make install \
    && cd .. \
    \
    # Build postgres-json-schema
    && git clone https://github.com/gavinwahl/postgres-json-schema \
    && cd postgres-json-schema \
    && make \
    && make install \
    && cd .. \
    \
    # Build pgsodium
    && git clone --branch $PGSODIUM_VERSION https://github.com/michelp/pgsodium \
    && cd pgsodium \
    && make \
    && make install

############################
# Final
############################
FROM citusdata/citus:latest
ARG POSTGIS_MAJOR

# Add extensions
COPY --from=ext_build /usr/share/postgresql/${PG_MAJOR}/ /usr/share/postgresql/${PG_MAJOR}/
COPY --from=ext_build /usr/lib/postgresql/${PG_MAJOR}/ /usr/lib/postgresql/${PG_MAJOR}/

RUN set -x \
    && apt-get update -y \
    && apt-get upgrade -y \
    && apt-get install --no-install-recommends -y curl lsb-release procps \
        libsodium23 \
        patroni \
        python3-consul \
        postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR \
        postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR-scripts \
        postgis \
        postgresql-$PG_MAJOR-pgrouting \
        postgresql-$PG_MAJOR-pgcron \
        postgresql-$PG_MAJOR-tdigest \
        postgresql-$PG_MAJOR-powa \
        postgresql-$PG_MAJOR-pg-stat-kcache \
        postgresql-$PG_MAJOR-pg-qualstats \
        postgresql-$PG_MAJOR-hypopg \
    \
    # Install WAL-G
    && curl -LO https://github.com/wal-g/wal-g/releases/download/v2.0.1/wal-g-pg-ubuntu-20.04-$(uname -m) \
    && install -oroot -groot -m755 wal-g-pg-ubuntu-20.04-$(uname -m) /usr/local/bin/wal-g \
    && rm wal-g-pg-ubuntu-20.04-$(uname -m) \
    \
    # Cleanup
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt/* \
    \
    # Add postgres to root group so it can read a private key for TLS
    # See https://github.com/hashicorp/nomad/issues/5020
    && gpasswd -a postgres root

RUN mkdir -p /docker-entrypoint-initdb.d
COPY ./files/000_shared_libs.sh /docker-entrypoint-initdb.d/000_shared_libs.sh
COPY ./files/001_initdb_postgis.sh /docker-entrypoint-initdb.d/001_initdb_postgis.sh

COPY ./files/update-postgis.sh /usr/local/bin
COPY ./files/docker-initdb.sh /usr/local/bin

USER postgres
CMD ["/usr/bin/patroni", "/etc/patroni/config.yml"]
