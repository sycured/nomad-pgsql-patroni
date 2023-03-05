#!/usr/bin/env bash

KEY_FILE=$PGDATA/pgsodium_root.key
cat <<EOF >$KEY_FILE
$PGSODIUM_KEY
cat $KEY_FILE
EOF

"/usr/bin/patroni", "/secrets/config.yml"