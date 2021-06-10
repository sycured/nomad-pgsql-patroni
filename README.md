# nomad-pgsql-patroni

A simple container running Postgres and Patroni useful for dropping directly into a Hashicorp environment (Nomad + Consul + Vault)

It also comes pre-baked with some tools and extensions

### Tools

| Name | Version | Link |
|--|--|--|
| awscli | 1.19.91 | https://pypi.org/project/awscli/ |
| WAL-G | 1.0 | https://github.com/wal-g/wal-g |
| Patroni | 2.0.2 | https://github.com/zalando/patroni |
| vaultenv | 0.13.1 | https://github.com/channable/vaultenv |

### Extensions

| Name | Version | Link |
|--|--|--|
| Timescale | 2.3.0 | https://www.timescale.com |
| PostGIS | 3.1.2 | https://postgis.net |
| pgRouting | 3.1.3 | https://pgrouting.org |
| postgres-json-schema | 0.1.1 | https://github.com/gavinwahl/postgres-json-schema |
| vector | 0.1.6 | https://github.com/ankane/pgvector |

### A note about TimescaleDB and Postgres 13

Timescale didn't initially support Postgre 13 so the 13.0 and 13.1 builds didn't provide it. Timescale 2.1.0 adds Postgres 13 support so from 13.2 this image includes Timescale again!

### Still running Postgres 11 or 12?

See the [`pg-11`](https://github.com/ccakes/nomad-pgsql-patroni/tree/pg-11) or [`pg-12`](https://github.com/ccakes/nomad-pgsql-patroni/tree/pg-12) branch for a maintained version.

## Usage
```hcl
# main.tf
resource "nomad_job" "postgres" {
  jobspec = "${file("${path.module}/job.hcl")}"
}

# job.hcl
job "your-task" {
  type = "service"
  dataceners = ["default"]

  vault { policies = ["postgres"] }

  group "your-group" {
    count = 3

    task "db" {
      driver = "docker"

      template {
        data <<EOL
scope: postgres
name: pg-{{env "node.unique.name"}}
namespace: /nomad

restapi:
  listen: 0.0.0.0:{{env "NOMAD_PORT_api"}}
  connect_address: {{env "NOMAD_ADDR_api"}}

consul:
host: consul.example.com
token: {{with secret "consul/creds/postgres"}}{{.Data.token}}{{end}}
register_service: true

# bootstrap config
EOL
      }

      config {
        image = "ccakes/nomad-pgsql-patroni:13.0-1.gis"

        port_map {
          pg = 5432
          api = 8008
        }
      }

      resources {
        memory = 1024

        network {
          port "api" {}
          port "pg" {}
        }
      }
    }
  }
}
```

## Testing

An example `docker-compose` file and patroni config is included to see this running.
```shell
$ docker-compose -f docker-compose.test.yml up
```

## ISSUES

Postgres runs as the postgres user however that user has been added to the root group. This probably has some security ramifications that I haven't thought of, but it's required for postgres to read TLS keys generated by Vault and written as templates.

[hashicorp/nomad#5020](https://github.com/hashicorp/nomad/issues/5020) is tracking (hopefully) a fix for this.
