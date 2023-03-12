job "postgres-15" {
  type        = "service"
  datacenters = ["saopaulo1"]

  constraint {
    attribute = "${attr.cpu.arch}"
    value     = "arm64"
  }

  update {
    max_parallel      = 1
    healthy_deadline  = "3m"
    progress_deadline = "10m"
    auto_revert       = false
    canary            = 0
  }

  group "pg15" {
    count = 4

    ephemeral_disk {
      migrate = true
      size    = 200
      sticky  = true
    }

    volume "postgresql" {
      type      = "host"
      source    = "postgresql"
      read_only = false
    }

    network {
      port api {
        static = 8008
        to     = 8008
      }
      port pg {
        static = 5432
        to     = 5432
      }
    }

    task "db" {
      driver = "podman"

      template {
        data = <<EOL
scope: postgres
name: pg-{{env "node.unique.name"}}
namespace: /pg

restapi:
  listen: 0.0.0.0:{{env "NOMAD_PORT_api"}}
  connect_address: {{env "attr.unique.network.ip-address"}}:{{env "NOMAD_PORT_api"}}

consul:
  host: {{env "attr.unique.network.ip-address"}}
  register_service: true

bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576
    postgresql:
      use_pg_rewind: true
      use_slots: true
      parameters:
        log_file_mode: "0640"
        log_filename: postgresql-%u.log
        log_rotation_age: 1d
        log_truncate_on_rotation: "on"
        max_connections: 120
        shared_buffers: 64MB
        work_mem: 16MB
        effective_cache_size: 512MB
        tcp_keepalives_idle: 300
        wal_level: "replica"
        password_encryption: scram-sha-256
        superuser_reserved_connections: 20

  method: local
  local:
    command: /usr/local/bin/docker-initdb.sh
    keep_existing_recovery_conf: True

  initdb:
  - encoding: UTF8
  - data-checksums

  pg_hba:
  - host  all           postgres  all scram-sha-256
  - host  replication   repl      all scram-sha-256
  - host  all           all       all scram-sha-256

  users:
    postgres:
      password: REPLACE-ME-POSTGRES
      options:
        - createrole
        - createdb
    repl:
      password: REPLACE-ME-REPL
      options:
        - replication

postgresql:
  listen: 0.0.0.0:5432
  connect_address: {{env "attr.unique.network.ip-address"}}:5432
  use_unix_socket: true
  data_dir: /alloc/pgdata/data
  authentication:
    replication:
      username: repl
      password: REPLACE-ME-REPL
    superuser:
      username: postgres
      password: REPLACE-ME-POSTGRES
EOL

        destination = "secrets/config.yml"
      }

      env {
        PGDATA       = "/alloc/pgdata/data"
        PGSODIUM_KEY = "REPLACE ME WITH: head -c 32 /dev/urandom | od -A n -t x1 | tr -d ' \n'"
      }

      config {
        image      = "docker.io/sycured/nomad-pgsql-patroni:latest"
        force_pull = true
        ports      = ["api", "pg"]
        volumes    = ["/opt/postgresql:/alloc/pgdata:rw"]
      }

      resources {
        cpu        = 750
        memory     = 512
        memory_max = 4096
      }
    }
  }
}
