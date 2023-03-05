#!/usr/bin/env bash
echo "timezone = 'UTC'" >>$PGDATA/postgresql.conf

echo "shared_preload_libraries = 'citus, pgsodium, pg_stat_statements, powa, pg_stat_kcache, pg_qualstats, pg_squeeze'" >>$PGDATA/postgresql.conf

echo "pg_stat_statements.max = 10000" >>$PGDATA/postgresql.conf
echo "pg_stat_statements.track = all" >>$PGDATA/postgresql.conf
echo "pgsodium.getkey_script = '$PGDATA/pgsodium_root.key'" >>$PGDATA/postgresql.conf