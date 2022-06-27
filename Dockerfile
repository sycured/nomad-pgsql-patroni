ARG GO_VERSION=1.17
ARG PG_MAJOR=14
ARG TIMESCALEDB_MAJOR=2
ARG POSTGIS_MAJOR=3

############################
# Build tools binaries in separate image
############################
FROM golang:${GO_VERSION} AS tools

RUN mkdir -p ${GOPATH}/src/github.com/timescale/ \
    && cd ${GOPATH}/src/github.com/timescale/ \
    && git clone https://github.com/timescale/timescaledb-tune.git \
    && git clone https://github.com/timescale/timescaledb-parallel-copy.git \
    # Build timescaledb-tune
    && cd timescaledb-tune/cmd/timescaledb-tune \
    && git fetch && git checkout --quiet $(git describe --abbrev=0) \
    && go get -d -v \
    && go build -o /go/bin/timescaledb-tune \
    # Build timescaledb-parallel-copy
    && cd ${GOPATH}/src/github.com/timescale/timescaledb-parallel-copy/cmd/timescaledb-parallel-copy \
    && git fetch && git checkout --quiet $(git describe --abbrev=0) \
    && go get -d -v \
    && go build -o /go/bin/timescaledb-parallel-copy

############################
# Build Postgres extensions
############################
FROM postgres:14 AS ext_build
ARG PG_MAJOR
ARG CITUS_VERSION=v11.0.2
ARG HLL_VERSION=v2.16
ARG TDIGEST_VERSION=v1.4.0
ARG TOPN_VERSION=v2.4.0

RUN set -x \
    && apt-get update -y \
    && apt-get install -y autoconf git curl apt-transport-https ca-certificates build-essential libpq-dev postgresql-server-dev-${PG_MAJOR} libcurl4-openssl-dev libkrb5-dev liblz4-dev libicu-dev libzstd-dev \
    && mkdir /build \
    && cd /build \
    \
    # Build pgvector
    && git clone --branch v0.2.2 https://github.com/ankane/pgvector.git \
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
    # build postgresql-hll
    && git clone -b $HLL_VERSION https://github.com/citusdata/postgresql-hll \
    && cd postgresql-hll \
    && make \
    && make install \
    && cd .. \
    # build postgresql-topn
    && git clone -b $TOPN_VERSION https://github.com/citusdata/postgresql-topn \
    && cd postgresql-topn \
    && make \
    && make install \
    && cd .. \
    # build tdigest
    && git clone -b $TDIGEST_VERSION https://github.com/tvondra/tdigest \
    && cd tdigest \
    && make \
    && make install \
    && cd .. \
    # build citus
    && git clone -b $CITUS_VERSION https://github.com/citusdata/citus \
    && cd citus \
    && ./configure \
    && make extension \
    && make install-extension

############################
# Add Timescale, PostGIS and Patroni
############################
FROM postgres:14
ARG PG_MAJOR
ARG POSTGIS_MAJOR
ARG TIMESCALEDB_MAJOR

# Add extensions
COPY --from=tools /go/bin/* /usr/local/bin/
COPY --from=ext_build /usr/share/postgresql/14/ /usr/share/postgresql/14/
COPY --from=ext_build /usr/lib/postgresql/14/ /usr/lib/postgresql/14/

RUN set -x \
    && apt-get update -y \
    && apt-get install -y gcc curl procps python3-dev libpython3-dev libyaml-dev apt-transport-https ca-certificates lsb-release \
    && echo "deb https://packagecloud.io/timescale/timescaledb/debian/ $(lsb_release -c -s) main" > /etc/apt/sources.list.d/timescaledb.list \
    && curl -L https://packagecloud.io/timescale/timescaledb/gpgkey | gpg --dearmor > /etc/apt/trusted.gpg.d/timescaledb.gpg \
    && apt-get update -y \
    && apt-cache showpkg postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR \
    && apt-get install -y --no-install-recommends \
        postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR \
        postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR-scripts \
        timescaledb-$TIMESCALEDB_MAJOR-postgresql-$PG_MAJOR \
        postgis \
        postgresql-$PG_MAJOR-pgrouting \
        postgresql-$PG_MAJOR-cron \
    \
    # Install Patroni
    && apt-get install -y --no-install-recommends \
        python3 python3-pip python3-setuptools \
    && pip3 install --upgrade pip \
    && pip3 install wheel zipp==1.0.0 \
    && pip3 install python-consul psycopg2-binary \
    && pip3 install https://github.com/zalando/patroni/archive/v2.1.3.zip \
    \
    # Install WAL-G
    && curl -LO https://github.com/wal-g/wal-g/releases/download/v2.0.0/wal-g-pg-ubuntu-20.04-amd64 \
    && install -oroot -groot -m755 wal-g-pg-ubuntu-20.04-amd64 /usr/local/bin/wal-g \
    && rm wal-g-pg-ubuntu-20.04-amd64 \
    \
    # Install vaultenv
    && curl -LO https://github.com/channable/vaultenv/releases/download/v0.14.0/vaultenv-0.14.0-linux-musl \
    && install -oroot -groot -m755 vaultenv-0.14.0-linux-musl /usr/bin/vaultenv \
    && rm vaultenv-0.14.0-linux-musl \
    \
    # Cleanup
    && rm -rf /var/lib/apt/lists/* \
    \
    # Add postgres to root group so it can read a private key for TLS
    # See https://github.com/hashicorp/nomad/issues/5020
    && gpasswd -a postgres root

RUN mkdir -p /docker-entrypoint-initdb.d
COPY ./files/000_shared_libs.sh /docker-entrypoint-initdb.d/000_shared_libs.sh
COPY ./files/001_initdb_postgis.sh /docker-entrypoint-initdb.d/001_initdb_postgis.sh
COPY ./files/002_timescaledb_tune.sh /docker-entrypoint-initdb.d/002_timescaledb_tune.sh

COPY ./files/update-postgis.sh /usr/local/bin
COPY ./files/docker-initdb.sh /usr/local/bin

USER postgres
CMD ["patroni", "/secrets/patroni.yml"]
