ARG PGVECTOR_VERSION=v0.4.0
ARG POSTGRES_MAJOR=15

FROM oraclelinux:9 as base
ARG POSTGRES_MAJOR
ENV PATH="/usr/pgsql-15/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
RUN dnf upgrade -y \
    && dnf install -y yum-utils https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm \
    && echo -e '[pgdg-common]\nname=PostgreSQL common RPMs for RHEL / Rocky $releasever - $basearch\nbaseurl=https://download.postgresql.org/pub/repos/yum/common/redhat/rhel-$releasever-$basearch\nenabled=1\ngpgcheck=0\nrepo_gpgcheck = 0\n[pgdg-rhel9-sysupdates]\nname=PostgreSQL Supplementary ucommon RPMs for RHEL / Rocky $releasever - $basearch\nbaseurl=https://download.postgresql.org/pub/repos/yum/common/pgdg-rocky9-sysupdates/redhat/rhel-$releasever-$basearch\nenabled=0\ngpgcheck=0\nrepo_gpgcheck = 0\n[pgdg-rhel9-extras]\nname=Extra packages to support some RPMs in the PostgreSQL RPM repo RHEL / Rocky $releasever - $basearch\nbaseurl=https://download.postgresql.org/pub/repos/yum/common/pgdg-rhel$releasever-extras/redhat/rhel-$releasever-$basearch\nenabled=0\ngpgcheck=0\nrepo_gpgcheck = 0\n[pgdg15]\nname=PostgreSQL 15 for RHEL / Rocky $releasever - $basearch\nbaseurl=https://download.postgresql.org/pub/repos/yum/15/redhat/rhel-$releasever-$basearch\nenabled=1\ngpgcheck=0\nrepo_gpgcheck = 0' >> /etc/yum.repos.d/pgdg.repo \
    && yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo \
    && dnf install -y postgresql${POSTGRES_MAJOR}-server postgresql${POSTGRES_MAJOR}-llvmjit \
    && rm -rf /var/cache/dnf/* \
    && mkdir /docker-entrypoint-initdb.d

############################
# Build Postgres extensions
############################
FROM base AS ext_build
ARG POSTGRES_MAJOR
ARG PGVECTOR_VERSION

RUN export PATH="/usr/pgsql-${POSTGRES_MAJOR}/bin:$PATH" \
    && dnf install --enablerepo=ol9_codeready_builder -y \
        ccache \
        git-core \
        postgresql${POSTGRES_MAJOR}-devel \
        redhat-rpm-config \
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
    && make install

############################
# Final
############################
FROM base as final
ARG POSTGRES_MAJOR
EXPOSE 5432 8008

# Add extensions
COPY --from=ext_build /usr/pgsql-${POSTGRES_MAJOR}/share/ /usr/pgsql-${POSTGRES_MAJOR}/share/
COPY --from=ext_build /usr/pgsql-${POSTGRES_MAJOR}/lib/ /usr/pgsql-${POSTGRES_MAJOR}/lib/

RUN dnf install --enablerepo=ol9_codeready_builder -y \
    nss_wrapper \
    citus_${POSTGRES_MAJOR}-llvmjit \
    pgsodium_${POSTGRES_MAJOR}-llvmjit \
    patroni \
    patroni-consul \
    pgrouting_${POSTGRES_MAJOR} \
    pg_cron_${POSTGRES_MAJOR} \
    tdigest_${POSTGRES_MAJOR} \
    hll_${POSTGRES_MAJOR} \
    postgresql_anonymizer_${POSTGRES_MAJOR}-llvmjit \
    powa_${POSTGRES_MAJOR} \
    pg_squeeze_${POSTGRES_MAJOR}-llvmjit \
    pg_stat_kcache_${POSTGRES_MAJOR} \
    pg_qualstats_${POSTGRES_MAJOR} \
    hypopg_${POSTGRES_MAJOR} \
    sequential_uuids_${POSTGRES_MAJOR}-llvmjit \
    topn_${POSTGRES_MAJOR}-llvmjit \
    && cpuarch=$(uname -m) \
    # Install WAL-G
    && [[ $cpuarch == x86_64 ]] && walg_arch=amd64 || walg_arch=aarch64 \
    && curl -LO https://github.com/wal-g/wal-g/releases/download/v2.0.1/wal-g-pg-ubuntu-20.04-$walg_arch \
    && install -oroot -groot -m755 wal-g-pg-ubuntu-20.04-$walg_arch /usr/local/bin/wal-g \
    && rm wal-g-pg-ubuntu-20.04-$walg_arch \
    && [[ $cpuarch == x86_64 ]] && gosu_arch=amd64 || gosu_arch=arm64 \
    && curl -LO https://github.com/tianon/gosu/releases/download/1.16/gosu-$gosu_arch \
    && install -oroot -groot -m755 gosu-$gosu_arch /usr/local/bin/gosu \
    && rm gosu-$gosu_arch \
    && [[ $cpuarch == x86_64 ]] && pgtimetable_arch=x86_64 || pgtimetable_arch=arm64 \
    && dnf install -y https://github.com/cybertec-postgresql/pg_timetable/releases/download/v5.3.0/pg_timetable_5.3.0_Linux_${pgtimetable_arch}.rpm \
    && rm -rf /var/cache/dnf/*

COPY ./files/000_shared_libs.sh /docker-entrypoint-initdb.d/000_shared_libs.sh
COPY ./files/001_initdb_postgis.sh /docker-entrypoint-initdb.d/001_initdb_postgis.sh
COPY ./files/update-postgis.sh /usr/local/bin
COPY ./files/docker-initdb.sh /usr/local/bin
COPY ./files/entrypoint.sh /usr/local/bin

USER postgres
CMD [ "/usr/local/bin/entrypoint.sh" ]
