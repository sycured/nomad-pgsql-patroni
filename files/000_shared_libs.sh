#!/usr/bin/env bash
echo "timezone = 'UTC'" >> $PGDATA/postgresql.conf

echo "shared_preload_libraries = 'citus, timescaledb, pg_stat_statements'" >> $PGDATA/postgresql.conf

echo "pg_stat_statements.max = 10000" >> $PGDATA/postgresql.conf
echo "pg_stat_statements.track = all" >> $PGDATA/postgresql.conf

echo "timescaledb.telemetry_level = off" >> $PGDATA/postgresql.conf
