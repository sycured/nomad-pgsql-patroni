#!/usr/bin/env bash

KEY_FILE=/alloc/pgdata/pgsodium_root.key
cat <<EOF >$KEY_FILE
$PGSODIUM_KEY
cat $KEY_FILE
EOF

exec /usr/bin/patroni /secrets/config.yml