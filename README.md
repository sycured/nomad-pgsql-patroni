# nomad-pgsql-patroni

A simple container running Postgres and Patroni useful for dropping directly into a Hashicorp environment (Nomad + Consul + Vault)

It also comes pre-baked with some tools and extensions

## Tools

| Name    | Link                               | Type of install |
| ------- | ---------------------------------- | --------------- |
| Patroni | https://github.com/zalando/patroni | Package         |
| WAL-G   | https://github.com/wal-g/wal-g     | Binary          |

## Extensions

| Name                 | Link                                              | Type of install |
| -------------------- | ------------------------------------------------- | --------------- |
| citus                | https://github.com/citusdata/citus                | Package         |
| hyperloglog          | https://github.com/citusdata/postgresql-hll       | Package         |
| hypopg               | https://github.com/HypoPG/hypopg                  | Package         |
| pg_cron              | https://github.com/citusdata/pg_cron              | Package         |
| pg_qualstats         | https://github.com/powa-team/pg_qualstats         | Package         |
| pg_stat_kcache       | https://github.com/powa-team/pg_stat_kcache       | Package         |
| pgrouting            | https://pgrouting.org                             | Package         |
| pgsodium             | https://github.com/michelp/pgsodium               | Build           |
| postgis              | https://postgis.net                               | Package         |
| postgres-json-schema | https://github.com/gavinwahl/postgres-json-schema | Build           |
| powa                 | https://github.com/powa-team/powa                 | Package         |
| tdigest              | https://github.com/tvondra/tdigest                | Package         |
| topn                 | https://github.com/citusdata/postgresql-topn      | Package         |
| vector               | https://github.com/ankane/pgvector                | Build           |

### Enable hypopg

```sql
CREATE EXTENSION hypopg;
```

### Enable powa

```sql
CREATE EXTENSION pg_stat_statements;
CREATE EXTENSION btree_gist;
CREATE EXTENSION powa;
CREATE EXTENSION pg_qualstats;
CREATE EXTENSION pg_stat_kcache;
```
